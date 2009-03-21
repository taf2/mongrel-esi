require File.join(File.dirname(__FILE__),'help.rb')

require 'esi/response'
require 'esi/esi'

class ResponseTest < Test::Unit::TestCase

  def test_response_to_response
    output = StringIO.new

    r1 = ESI::Response.new( output )
    r2 = ESI::Response.new( r1.active_buffer )

    buffer = r2.reserve_buffer
    t = Thread.new do
      buffer << "hello"
      sleep(0.01) # make it count
      buffer.close_write
    end

    r2.wait_thread(t)

    r2.flush

    r1.flush

    output.rewind

    assert_equal "hello", output.read

  end

  def test_esi_parser
    output = []
    @response = ESI::Response.new( output )
    @parser = ESI::CParser.new
    @count = 0

    @parser.end_tag_handler do|tag_name|
      tag_buffer = @response.partial_buffer
      thread = Thread.new(tag_buffer,@count) do|buffer,count|
        buffer << "#{count}: sample"
        buffer.close_write
      end
      @response.wait_thread( thread )
    end

    input = StringIO.new(INPUT_STREAM)
    lines = input.readlines

    @parser.output_handler do|chars|
      @response.send
      @response.active_buffer << chars
    end

    for line in lines do
      @parser.process line
      @count += 1
    end

    @parser.finish
    @response.flush
#    puts output.join("")
#    puts output.join("").split("\n").size

    # break it back up into lines
    lines = output.join("").split("\n")
    assert_equal 35, lines.size

    assert_match(/hello there world/,lines[1])
    assert_match(/sample/,lines[3])
    assert_match(/sample/,lines[7])
    assert_match(/sample/,lines[13])
    assert_match(/and some more here/,lines[15])
    assert_match(/sample/,lines[19])
    assert_match(/sample/,lines[20])
    assert_match(/sample/,lines[21])
    assert_match(/sample/,lines[22])
    assert_match(/and some more here/,lines[24])
    assert_match(/sample/,lines[25])
    assert_match(/sample/,lines[31])

  end

  def test_sample
    lines = INPUT_STREAM.split("\n")

    timer = Time.now
    request_delay = 0.01 # each request takes 
    request_vary = 0.0005 # the request delay varies
    response_delay = 0.00005 # the delay in reading the surrogate request
    output = []
    response = ESI::Response.new( output )

    count = 0

    lines.each do|line|
      line += "\n"

      sleep response_delay

      if line.match(/<esi:/)
        msg_buffer = response.partial_buffer

        thread = Thread.new(msg_buffer,count) do|buffer,count|
          sleep( (request_delay + (rand > 0.5 ? (-1* request_vary) : request_vary)).abs) # some busy work
          message = "#{count}: sample\n"
          buffer << message
          buffer.close_write
        end

        response.wait_thread( thread )
      else
        response.active_buffer << "#{count}: #{line}"
      end
      count += 1
      response.send
    end

    response.flush
  
    output = output.join("").split("\n")

    assert_equal 35, output.size
    assert_match(/\s/,output[0])
    assert_match(/hello there world/,output[1])
    assert_match(/sample/,output[3])
    assert_match(/sample/,output[7])
    assert_match(/sample/,output[13])
    assert_match(/and some more here/,output[15])
    assert_match(/sample/,output[19])
    assert_match(/sample/,output[20])
    assert_match(/sample/,output[21])
    assert_match(/sample/,output[22])
    assert_match(/and some more here/,output[24])
    assert_match(/sample/,output[25])
    assert_match(/sample/,output[31])
    assert_match(/\s/,output[34])

    #puts output.join("\n")
    #puts "total time: #{Time.now - timer} seconds, with a request delay of #{request_delay} seconds with variance of #{request_vary} and total of #{count} lines taking #{response_delay} seconds each to read."
  end

  # define a sample buffer here:
  INPUT_STREAM = %Q(
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
end
