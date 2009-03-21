# Copyright (c) 2008 Todd A. Fisher
# see LICENSE
require 'fastthread'
require 'thread'
require 'stringio'

module ESI
  # this class allows me to write, <<, or call
  # an object to send it bytes, priority being <<, then write, then call
  class OutputAdapter
    attr_reader :device
    def initialize(output_device)
      @device = output_device
      if @device.respond_to?(:<<)
        self.instance_eval do
          def << (msg)
            @device << msg
          end
        end
      elsif @device.respond_to?(:write)
        self.instance_eval do
          def << (msg)
            @device.write msg
          end
        end
      elsif @device.respond_to?(:call)
        self.instance_eval do
          def << (msg)
            @device.call msg
          end
        end
      end
    end

  end

  class Response
    attr_reader :active_buffer
    attr_accessor :output

    def initialize( output )
      @count = 0
      @back_buffer = []
      @output = OutputAdapter.new(output)
      @last_out = 0
      @threads = []
      @active_buffer = reserve_buffer
    end

    def update_output(output)
      @output = output
    end

    def partial_buffer
      @active_buffer.close_write
      temp = reserve_buffer
      @active_buffer = reserve_buffer
      temp
    end

    # return's new buffer
    def reserve_buffer
      buffer = @back_buffer[@count] = StringIO.new
      @count += 1
      buffer
    end

    def send
      check_buffers = @back_buffer[@last_out..@count]

      for buffer in check_buffers do
        break if buffer.nil? or !buffer.closed_write?
        buffer.rewind
        @output << buffer.read
        @last_out += 1
      end
    end

    def wait_thread(thread)
      @threads << thread
    end

    def flush
      @threads.each{|t| t.join }
      @active_buffer.close_write if !@active_buffer.closed_write?
      # roll up requests
      @last_out = 0 if @last_out == -1
      tail_buffer = (@back_buffer[@last_out..@back_buffer.size]||[])
      #puts "\nflushing: #{tail_buffer.inspect} from #{@back_buffer.inspect}"
      while !tail_buffer.empty?
        o = tail_buffer.shift
        unless o.nil?
          o.rewind
          buf = o.read
          #puts "flush : #{buf.inspect}"
          @output << buf
        end
        #puts "#{self} sending: #{@count-tail_buffer.size}"
      end
    end

  end
end
