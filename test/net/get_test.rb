require 'socket'
require 'rubygems'
require 'fastthread'
require 'thread'
require 'benchmark'
require "#{File.dirname(__FILE__)}/net_helper"

if RUBY_VERSION < '1.8.5'
  STDERR.puts "This test requires at a minum ruby 1.8.5 for asynchronous i/o routines"
  exit(1)
end

# evalutate different paterns for retrieving multiple documents at the same time

class Array

  def invert
    h={}
    self.each_with_index{|x,i| h[x]=i}
    h
  end

end


module SocketTests
  include Socket::Constants
  extend self
  READ = 0
  WRITE = 1

  def simple_get(host)
    host, port = host.split(':')
    socket = Socket.new( AF_INET, SOCK_STREAM, 0 )
    sockaddr = Socket.pack_sockaddr_in( port, host )
    socket.connect( sockaddr )
    socket.write( "GET / HTTP/1.0\r\n\r\n" )
    socket.read
  end

  def blocking_get(hosts)
    results = {}
    hosts.each do|host|
      results[:host] = simple_get(host)
      STDERR.print "."
    end
    results
  end

  def multithreaded_get(hosts)
    results = Queue.new
    id=0
    ids = []
    threads = hosts.collect do|host|
      thread = Thread.new(host,id) do|host,tid|
        result = simple_get(host)
        results << { :buffer => result, :host => host, :id => tid }
      end
      ids << id
      id += 1
      thread
    end
    until ids.empty?
      result = results.pop
      STDERR.print "." #result size => #{result[:buffer].size} from host => #{result[:host]}"
      ids.reject!{|id| id == result[:id]}
    end
    threads.each do|t|
      t.join
    end
    results
  end

  def nonblocking_get(hosts)
    results = {}

    sockets = hosts.collect do|host|
      host, port = host.split(':')
      socket = Socket.new(AF_INET, SOCK_STREAM, 0)
      sockaddr = Socket.sockaddr_in(port, host)
      socket.connect_nonblock(sockaddr) rescue Errno::EINPROGRESS
      results[socket] = { :host => host, :buffer => "" }
      socket
    end
    writes = sockets
    reads = []

    begin
      ready = IO.select(reads, writes,[],10)
      ready[WRITE].each do|socket|
        socket.write("GET / HTTP/1.0\r\n\r\n")
        reads << socket
        # remove the write from the write pool
        writes = writes.reject{|s| s == socket}
      end

      ready[READ].each do|socket|
        begin
          result = results[socket]
          result[:buffer] << socket.read_nonblock(2048)
        rescue EOFError
          # finished, report on results
          STDERR.print "."
          # remove the socket from the read pool
          reads.reject!{|s| s == socket}
        end
      end
    #  break if (reads.empty? and writes.empty?)
    #  ready = IO.select(reads, writes)
    end until (reads.empty? and writes.empty?)

    results
  end
end

TRIALS=5
DELAY=0.5
PORT_START=9990
PORT_END=9999

def network_trial_average(trial, &block)
  STDERR.print "average: #{trial}  "
  b = Benchmark.measure do
    TRIALS.times do|i|
      yield
      sleep DELAY
    end
  end
  time = b.real - (DELAY*TRIALS)
  STDERR.puts "( #{time/TRIALS} seconds )"
  time/TRIALS
end

def network_trial_variance(trial, average, &block)
  STDERR.print "variance: #{trial}  "
  sumsqrs = 0
  TRIALS.times do|i|
    timer = Time.now
    yield
    sleep DELAY
    duration = (Time.now - timer) - DELAY
    sumsqrs += ((duration - average) * (duration - average))
  end
  STDERR.puts "( #{sumsqrs/TRIALS} seconds )"
  sumsqrs/TRIALS
end

multi_trials_average = 0
sync_trials_average = 0
async_trials_average = 0
test_servers = []
test_hosts = []

((PORT_END+1)-PORT_START).times do|port|
  port = PORT_START + port
  config = start_net_server(port)
  test_servers << config
  test_hosts << "127.0.0.1:#{port}"
end
puts "started #{test_hosts.size} servers..."

pid = fork do
  test_average = [ lambda {multi_trials_average += network_trial_average("Multi trial") { SocketTests.multithreaded_get(test_hosts) }},
                   lambda {sync_trials_average += network_trial_average("Sync trial") { SocketTests.blocking_get(test_hosts) }},
                   lambda {async_trials_average += network_trial_average("ASync trial") { SocketTests.nonblocking_get(test_hosts) }} ]
  test_variance = [ lambda {network_trial_variance("Multi trial",multi_trials_average) { SocketTests.multithreaded_get(test_hosts) }},
                    lambda {network_trial_variance("Sync trial",sync_trials_average) { SocketTests.blocking_get(test_hosts) }},
                    lambda {network_trial_variance("ASync trial",async_trials_average) { SocketTests.nonblocking_get(test_hosts) }} ]

  # first pass run forwards and backwards
  test_average.each { |trial| trial.call }

  # now with averages compute std
  test_variance.each {|trial| trial.call }

  # run in reverse
  multi_trials_average = 0
  sync_trials_average = 0
  async_trials_average = 0
  test_average.reverse.each { |trial| trial.call }
  test_variance.reverse.each { |trial| trial.call }

  # seconds pass reorder tests by swapping odd/even
#  even = tests.invert.collect{ |trial,index| trial if (index % 2) == 0 }.compact
#  odd = tests.invert.collect{ |trial,index| trial if (index % 2) == 1 }.compact
#  tests = (odd + even).flatten
  # rerun
#  tests.each { |trial| trial.call }
#  tests.reverse.each { |trial| trial.call }
  puts  "Multi-Threads Average => #{multi_trials_average}"
  puts  "Syncrhonous Average => #{sync_trials_average}"
  puts  "ASyncrhonous Average => #{async_trials_average}"
end

Process::waitpid(pid,0)

test_servers.each {|server| server.shutdown }
