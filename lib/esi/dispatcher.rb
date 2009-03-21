require 'mongrel'
require 'esi/proxy'
require 'esi/logger'

module ESI

  class Dispatcher < Mongrel::HttpHandler
    attr_reader :config
    include ESI::Log

    Thread.abort_on_exception = false

    def initialize( options )
      super()
      @config = ESI::Config.new( options )
    end

    def process(request, response)
      start = Time.now

      url = @config.router.url_for(request.params["REQUEST_URI"])

      chunk_count, bytes_sent, status, sent_from_cache = ESI::Proxy.new(@config).process(url, request,response)

    rescue => e
      log_error "\n#{e.message}: error at #{e.backtrace.first} msg at #{__FILE__}:#{__LINE__}\n"
    ensure
      log_request "\n#{url}, #{Time.now - start} seconds with status #{status} #{sent_from_cache ? "from cache" : ''} and #{chunk_count} chunks, #{bytes_sent} bytes\n"
    end

  end
end
