#!/usr/bin/env ruby
require 'uri'
require 'socket'
require 'rubygems'
require 'fastthread'
require 'thread'
require 'rev'

# measure perf of different I/O request patterns
# it's a bit variable because we're doing concurrent requests
# against samples/simple/simple.rb

module Baseline
  class IOTest
    attr_reader :requests
    def initialize(requests)
      @requests = requests
    end

    def run
      @timer = Time.now
      execute
      @duration = Time.now - @timer
    end

    def verify(responses)
      total_bytes = 0
      @results.each {|url,buf| total_bytes += buf.size }
      print "#{self.class} Requested :#{@results.size} of #{total_bytes} bytes "
      puts "executed: #{@duration} seconds"

      responses.each do|key,pair|
        if @results[key] != pair.last
          puts "invalid or incomplete response for #{pair.first}"
          puts @results[key]
          puts "================="
          puts pair.last
          exit(1)
        end
      end
    end
  end
  
  # use standard ruby Threads
  class Threaded < IOTest
    def execute
      threads = []
      @requests.each_with_index do|url_req,id|
        threads << Thread.new(url_req,id) do|url,id|
          uri = URI.parse(url)
          socket = Socket.new( Socket::Constants::AF_INET, Socket::Constants::SOCK_STREAM, 0 )
          socket.connect( Socket.pack_sockaddr_in( uri.port, uri.host ) )
          socket.write( "GET #{uri.path} HTTP/1.0\r\n\r\n" )
          buf = socket.read
          #puts "reading #{url}\n#{buf}\n"
          [id, buf]
        end
      end
      @results = {}
      threads.each do |t|
        id, result = t.value
        @results[id] = result
      end
    end
  end

  # use standard ruby IO.select
  class Selected < IOTest
    SOCK_READ = 0
    SOCK_WRITE = 1
    SOCK_ERROR = 2
    
    def execute
      @sockets = {}
      @results = {}
      @reads = []
      @writes = []
      @errors = []

      @requests.each_with_index do|url,id|
        uri = URI.parse(url)
        socket = Socket.new(Socket::Constants::AF_INET, Socket::Constants::SOCK_STREAM, 0)
        sockaddr = Socket.sockaddr_in(uri.port, uri.host)
        begin
          socket.connect_nonblock(sockaddr)
        rescue Errno::EINPROGRESS => e
        end
        @sockets[socket] = { :id => id, :uri => uri, :buffer => "" }
        @writes << socket
      end
      while !@reads.empty? or !@writes.empty? or !@errors.empty?
        ready = IO.select(@reads, @writes, @errors,1)
        if ready and !ready.empty?

          ready[SOCK_READ].each do|sock|
            on_read(sock)
          end
 
          ready[SOCK_WRITE].each do|sock|
            on_write(sock)
          end
 
          ready[SOCK_ERROR].each do|sock|
            on_error(sock)
          end

        else
          on_timeout
        end
      end
    end

    def on_read(socket)
      
      @sockets[socket][:buffer] << socket.read_nonblock(2048)
    rescue EOFError
      # remove the socket from the read pool
      @reads.reject!{|s| s == socket}
      on_finish( socket )
    end

    def on_write(socket)
      uri = @sockets[socket][:uri]
      # send the request
      socket.write("GET #{uri.path} HTTP/1.0\r\n\r\n")
      # load socket into reads pool
      @reads << socket
      # remove the write from the write pool
      @writes.reject!{|s| s == socket}
    end

    def on_error(socket)
    end

    def on_finish(socket)
      @results[@sockets[socket][:id]] = @sockets[socket][:buffer]
      socket.close
    end

    def on_timeout
    end
  end

  # use rev event library
  class Evented < IOTest
    class Requester < Rev::HttpClient
      attr_accessor :uri, :id, :buffer
      attr_accessor :results

      def self.start( uri, id, revloop )
        client = connect( uri.host, uri.port )
        client.id = id
        client.buffer = Rev::Buffer.new
        client.attach(revloop)
      end
 
      def on_read(data)
        @buffer << data
        super
      end

      def on_body_data(data)
        # sshhh
      end

      def on_close
        @results[@id] = @buffer.read
      end

    end

    def execute
      @results = {}
      revloop = Rev::Loop.new
      clients = []
      @requests.each_with_index do|url,id|
        uri = URI.parse(url)
        client = Requester.start(uri,id,revloop)
        client.results = @results
        client.request('GET',uri.path)
      end
      revloop.run
    end
  end
end

# test requesting each sequence, this is simulating the io pattern in mongrel
def run_in_thread( requests, responses, klass, req_count )
  timer = Time.now
  threads = []
  req_count.times do
    test = klass.new(requests)
    t = Thread.new(test) do|ntest|
      ntest.run
      ntest
    end
    threads << t
  end
  threads.each {|t| t.value.verify(responses) }
  puts "#{klass} Duration: #{Time.now - timer}"
end

def serial_request( requests )
  responses = {}
  timer = Time.now
  requests.each_with_index do|url,id|
    uri = URI.parse(url)
    socket = Socket.new( Socket::Constants::AF_INET, Socket::Constants::SOCK_STREAM, 0 )
    sockaddr = Socket.pack_sockaddr_in( uri.port, uri.host )
    socket.connect( sockaddr )
    socket.write( "GET #{uri.path} HTTP/1.0\r\n\r\n" )
    responses[id] = [url,socket.read]
  end
  puts "serial requests in #{Time.now - timer}"
  responses
end

# our sample page makes the following fragment requests starting each in this order:
# see samples/simple/simple.rb
requests = [
  'http://127.0.0.1:3001/frag1/',
  'http://127.0.0.1:3002/frag2/',
  'http://127.0.0.1:3003/frag3/',
  'http://127.0.0.1:3004/frag4/',
  'http://127.0.0.1:3001/frag1/',
  'http://127.0.0.1:3002/frag2/',
  'http://127.0.0.1:3004/frag4/',
  'http://127.0.0.1:3001/frag1/',
  'http://127.0.0.1:3003/frag3/'
]

# collect the responses and warm up servers
responses = serial_request( requests )

Ncount = 10

run_in_thread( requests, responses, Baseline::Selected, Ncount )
sleep 0.5

run_in_thread( requests, responses, Baseline::Threaded, Ncount )
sleep 0.5

# this won't work with rev, unless we create a unique event loop per thread, but that would really defeat the purpose? 
run_in_thread( requests, responses, Baseline::Evented, Ncount )
