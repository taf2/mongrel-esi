require 'socket'
require 'thread'
require 'benchmark'
require "#{File.dirname(__FILE__)}/net_helper"
require 'test/unit'

# open up the mongrel http server
# reimplement with nonblocking io
module Mongrel

  class HttpServer
    READ = 0
    WRITE = 1
    ERROR = 2

    # Does the majority of the IO processing.  It has been written in Ruby using
    # about 7 different IO processing strategies and no matter how it's done 
    # the performance just does not improve.  It is currently carefully constructed
    # to make sure that it gets the best possible performance, but anyone who
    # thinks they can make it faster is more than welcome to take a crack at it.
    def process_client(client)
      begin
        parser = HttpParser.new
        params = HttpParams.new
        request = nil
        data = client.readpartial(Const::CHUNK_SIZE)
        nparsed = 0

        # Assumption: nparsed will always be less since data will get filled with more
        # after each parsing.  If it doesn't get more then there was a problem
        # with the read operation on the client socket.  Effect is to stop processing when the
        # socket can't fill the buffer for further parsing.
        while nparsed < data.length
          nparsed = parser.execute(params, data, nparsed)

          if parser.finished?
            if not params[Const::REQUEST_PATH]
              # it might be a dumbass full host request header
              uri = URI.parse(params[Const::REQUEST_URI])
              params[Const::REQUEST_PATH] = uri.request_uri
            end

            raise "No REQUEST PATH" if not params[Const::REQUEST_PATH]

            script_name, path_info, handlers = @classifier.resolve(params[Const::REQUEST_PATH])

            if handlers
              params[Const::PATH_INFO] = path_info
              params[Const::SCRIPT_NAME] = script_name
              params[Const::REMOTE_ADDR] = params[Const::HTTP_X_FORWARDED_FOR] || client.peeraddr.last

              # select handlers that want more detailed request notification
              notifiers = handlers.select { |h| h.request_notify }
              request = HttpRequest.new(params, client, notifiers)

              # in the case of large file uploads the user could close the socket, so skip those requests
              break if request.body == nil  # nil signals from HttpRequest::initialize that the request was aborted

              # request is good so far, continue processing the response
              response = HttpResponse.new(client)

              # Process each handler in registered order until we run out or one finalizes the response.
              handlers.each do |handler|
                handler.process(request, response)
                break if response.done or client.closed?
              end

              # And finally, if nobody closed the response off, we finalize it.
              unless response.done or client.closed? 
                response.finished
              end
            else
              # Didn't find it, return a stock 404 response.
              client.write(Const::ERROR_404_RESPONSE)
            end

            break #done
          else
            # Parser is not done, queue up more data to read and continue parsing
            chunk = client.readpartial(Const::CHUNK_SIZE)
            break if !chunk or chunk.length == 0  # read failed, stop processing

            data << chunk
            if data.length >= Const::MAX_HEADER
              raise HttpParserError.new("HEADER is longer than allowed, aborting client early.")
            end
          end
        end
      rescue EOFError,Errno::ECONNRESET,Errno::EPIPE,Errno::EINVAL,Errno::EBADF
        client.close rescue Object
      rescue HttpParserError
        if $mongrel_debug_client
          STDERR.puts "#{Time.now}: BAD CLIENT (#{params[Const::HTTP_X_FORWARDED_FOR] || client.peeraddr.last}): #$!"
          STDERR.puts "#{Time.now}: REQUEST DATA: #{data.inspect}\n---\nPARAMS: #{params.inspect}\n---\n"
        end
      rescue Errno::EMFILE
        reap_dead_workers('too many files')
      rescue Object
        STDERR.puts "#{Time.now}: ERROR: #$!"
        STDERR.puts $!.backtrace.join("\n") if $mongrel_debug_client
      ensure
        client.close rescue Object
        request.body.delete if request and request.body.class == Tempfile
      end
    end

    def run
      BasicSocket.do_not_reverse_lookup=true

      configure_socket_options

      if $tcp_defer_accept_opts
        @socket.setsockopt(*$tcp_defer_accept_opts) rescue nil
      end
      @running = true

      @acceptor = Thread.new do
        readers = [@socket]
        writers = []
        errors = []
        @timeout = @timeout <= 0 ? 1 : @timeout
        puts @timeout.inspect

        while @running
 
          begin
            begin
              client_socket, client_sockaddr = @socket.accept_nonblock
            rescue Errno::EAGAIN, Errno::ECONNABORTED, Errno::EPROTO, Errno::EINTR
              if $tcp_cork_opts
                client_socket.setsockopt(*$tcp_cork_opts) rescue nil
              end
              readers << client_socket if client_socket
              ready = IO.select(readers, writers, errors, @timeout)

              puts "Socket ready => #{readers.size}, #{client_socket.inspect}\n#{ready.inspect}"
              if ready 

                ready[READ].each do|client|
                  if read_from_client(client)
                    ready[READ].reject do|c| c == client end
                  end
                end

                ready[WRITE].each do|client|
                  write_to_client(client)
                end

                ready[ERROR].each do|client|
                end

              end

            end
            puts @running 

          rescue StopServer
            puts "recieved stop"
            @socket.close rescue Object
            break
          rescue Errno::EMFILE
            reap_dead_workers("too many open files")
            sleep 0.5
          rescue Errno::ECONNABORTED
            # client closed the socket even before accept
            client.close rescue Object
          rescue Object => exc
            STDERR.puts "!!!!!! UNHANDLED EXCEPTION! #{exc.class}:#{exc}.  TELL ZED HE'S A MORON."
            STDERR.puts $!.backtrace.join("\n")# if $mongrel_debug_client
            exit 1
          end
        end
        graceful_shutdown
      end

      return @acceptor
    end

    def read_from_client(socket)
      begin
        result = socket.read_nonblock(Const::CHUNK_SIZE) 
      rescue Errno::EAGAIN, EOFError
        puts "done"
        return true
      rescue Errno::ENOTCONN
      end
      puts result
      return false
    end
 
    def write_to_client(socket)
    end
    
    # Stops the acceptor thread and then causes the worker threads to finish
    # off the request queue before finally exiting.
    def stop
      puts "send stop"
      @running = false
      stopper = Thread.new do 
        exc = StopServer.new
        @acceptor.raise(exc)
      end
      stopper.priority = 10
    end

  end

end

class TestServer < Test::Unit::TestCase

  def setup
    @server = start_net_server(9999)
  end

  def teardown
    puts "call stop"
    @server.stop
  end

=begin
  def test_single_request
    res = issue_request
    puts "request complete"
    assert_not_nil res
    assert_not_nil res.header
    assert_not_nil res.body
    assert_equal Net::HTTPOK, res.header.class
    assert_match "Test Document", res.body, "Document body missing"
  end
  def test_multiple_request
    puts Benchmark.measure {
      threads = []
      2.times do
        threads << Thread.new do
          res = issue_request
          assert_equal Net::HTTPOK, res.header.class
        end
      end
      threads.each do|t| t.join end
    }
  end
=end

  def issue_request
    Net::HTTP.start("127.0.0.1", 9999) { |h| h.get("/") }
  end

end
