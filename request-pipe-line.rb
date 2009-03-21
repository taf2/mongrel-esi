# reading a file
# as we read and encounter <esi:include src="/foo"/>
# spawn a thread and simulate requesting, but continue parsing the file looking for more on the main thread
# tweak the sleep calls to get different behavior...
$:.unshift File.join(File.dirname(__FILE__),'ext')
$:.unshift File.join(File.dirname(__FILE__),'lib')
require 'rubygems'
require 'esi/esi'
require 'esi/response'
require 'thread'

# define a sample buffer here:
input_stream = %Q(
  hello there world

  <esi:include src='/foo/'/>

  some more bytes here
  
  <esi:include src='/bar/'/>

  and some more here
  
  some more bytes here
  
  <esi:include src='/bar/'/>

  and some more here
  
  some more bytes here
  
  <esi:include src='/bar/'/>
  <esi:include src='/bar/'/>
  <esi:include src='/bar/'/>
  <esi:include src='/bar/'/>

  and some more here
  <esi:include src='/bar/'/>

  and some more here
  
  some more bytes here
  
  <esi:include src='/bar/'/>

  and some more here
)

=begin
# lets read line by line
class MessageQueue
  attr_reader :output

  def initialize( output )
    @lock = Mutex.new
    @count = 0
    @back_buffer = []
    @output = output
    @last_out = -1
  end

  # return's id
  def reserve_message
    @lock.synchronize do
      @back_buffer[@count]
      @count += 1
      (@count-1)
    end
  end

  def back_buffer(id,body)
    @lock.synchronize do
      @back_buffer[id] = body
    end
  end

  def send_message(body)
    @lock.synchronize do
      @back_buffer[@count] = body # buffer current message
      # roll up requests
      until @last_out == @count
        o = @back_buffer[@last_out+1]
        if o.nil?
          puts "buffering..."
          break
        end
        puts "sending: #{@last_out+1}"
        @back_buffer[@last_out+1] = nil # clear it out, release memory
        @output << o
        @last_out += 1
      end
    end
    @count += 1
  end

  def flush
    # roll up requests
    tail_buffer = (@back_buffer[@last_out..@back_buffer.size]||[])
    while !tail_buffer.empty?
      o = tail_buffer.shift
      @output << o unless o.nil?
      puts "sending: #{@count-tail_buffer.size}"
    end
  end

end
=end
lines = input_stream.split("\n")

timer = Time.now
request_delay = 0.01 # each request takes 
request_vary = 0.0005 # the request delay varies
response_delay = 0.00005 # the delay in reading the surrogate request

output = []
message_queue = ESI::Response.new( output )

count = 0
lines.each do|line|
  sleep response_delay
  msg_buffer = message_queue.reserve_buffer
  if line.match(/<esi:/)
    thread = Thread.new(msg_buffer,count) do|buffer,count|
      sleep( (request_delay + (rand > 0.5 ? (-1* request_vary) : request_vary)).abs) # some busy work
      message = "#{count}: sample"
      msg_buffer << message
      msg_buffer.close_write
    end
    message_queue.wait_thread( thread )
  else
    msg_buffer << "#{count}: #{line}"
    msg_buffer.close_write
  end
  count += 1
  message_queue.send
end

message_queue.flush

puts message_queue.output.join("\n")
puts "total time: #{Time.now - timer} seconds, with a request delay of #{request_delay} seconds with variance of #{request_vary} and total of #{count} lines taking #{response_delay} seconds each to read."
