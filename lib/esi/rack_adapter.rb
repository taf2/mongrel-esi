require 'rubygems'
require 'rack'
require 'rack/request'
require 'rack/response'
if $0 == __FILE__
  $:.unshift File.join(File.dirname(__FILE__),'..')
  $:.unshift File.join(File.dirname(__FILE__),'..','..','ext')
end
require 'esi/logger'
require 'esi/config'
require 'esi/proxy'

module ESI
  # override how config works for rack
  class RackConfig
    def self.enable
      ESI::Config.class_eval do
        def self.config
          @@config ||= ESI::Config.new( {} )
        end
        def self.define(listeners=nil)
          puts ESI::Config.config.inspect
          yield ESI::Config.config
          puts ESI::Config.config.inspect
        end
      end
      nil
    end
  end

  # create wrappers for request
  class ESI::Request < Rack::Request
    def params
      env
    end
    def request_params
      self.GET.update(self.POST)
    end
  end

  # create wrappers for response
  #class ESI::Response < Rack::Response
  #  class Writer
  #    def initialize( writer )
  #      @writer = writer
  #    end
  #    def write(data)
  #      @writer.write( data )
  #    end
  #  end
  #  def socket
  #    Writer.new(self)
  #  end
  #end

  class RackAdapter
    attr_reader :config
    include ESI::Log

    def initialize( config )
      @config = config
    end

    def call(env)
      start = Time.now
      request = ESI::Request.new(env)
      puts request.params["HTTP_VERSION"]

      url = @config.router.url_for(request.params["REQUEST_URI"])

      chunk_count = 0, bytes_sent = 0, status = 200, sent_from_cache = false
      Rack::Response.new.finish do |response|
        begin
          chunk_count, bytes_sent, status, sent_from_cache = ESI::Proxy.new(@config).process(url, request, response)
        rescue => e
          log_error "\n#{e.message}: error at #{e.backtrace.first} msg at #{__FILE__}:#{__LINE__}\n"
        ensure
          log_request "\n#{url}, #{Time.now - start} seconds with status #{status} #{sent_from_cache ? "from cache" : ''} and #{chunk_count} chunks, #{bytes_sent} bytes\n"
        end
      end

    end

    def each
    end

  end
end

if $0 == __FILE__
  require 'rubygems'
  require 'ebb'
  require 'yaml'
  listeners = ESI::RackConfig.enable
  eval( File.read(File.join(File.dirname(__FILE__),'..','..','samples','configs','config.rb')) )
  Ebb.start_server(ESI::RackAdapter.new(ESI::Config.config), :port => 4444)
end
