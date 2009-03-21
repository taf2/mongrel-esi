# Copyright (c) 2008 Todd A. Fisher
# see LICENSE
require 'uri'
require 'timeout'
require 'net/http'
require 'esi/logger'
require 'esi/cache'
require 'esi/config'
require 'esi/router'
require 'esi/processor'
require 'esi/version'
require 'mongrel'
#require 'resolv-replace'

# http://arosien.blogspot.com/2007/06/increasing-rubys-netbufferedio-buffer.html
# patch net::http to increase buffer size
#module Net
#  class BufferedIO
#    def rbuf_fill
#      timeout(@read_timeout) { @rbuf << @io.sysread(16384) }
#    end
#  end
#end

module ESI

  class Proxy 
    attr_reader :config, :router, :cache_buffer
    include ESI::Log
    SERVER="mongrel-esi/#{ESI::VERSION::STRING}"

    def initialize( config )
      @config = config
      @router = config.router
      @cache_buffer = nil
    end

    def process(url, request, response)
 
      status = 200

      http_params = http_params(request.params)

      chunk_count = 0
      bytes_sent = 0
      sent_from_cache = false
      uri = URI.parse(url)

      path_with_query = uri.query ? "#{uri.path}?#{uri.query}" :  uri.path
 
      # check if the origin is cached
      cached_page = @config.cache.get( path_with_query, http_params )
      if cached_page and cached_page.valid?
        cache_buffer = cached_page.body
        head, body = cache_buffer.split("\r\n\r\n")
        buffer = StringIO.new
        bytes_sent = send_esi_buffered( buffer, request, http_params, body )
        buffer.rewind
        bytes_sent = buffer.size
        #puts bytes_sent.inspect
        head = head.sub(/Content-Length:.*$/,"Content-Length: #{bytes_sent}")
        #puts head
        response.write head
        response.write "\r\n\r\n"
        response.write buffer.read
        response.done = true if response.respond_to?(:done)
        sent_from_cache = true
      else
        proxy_request = (request.params["REQUEST_METHOD"] == "POST") ?
                            Net::HTTP::Post.new( path_with_query, http_params ) :
                            Net::HTTP::Get.new( path_with_query, http_params )

        # open the conneciton up so we can start to stream the connection
        Net::HTTP.start(uri.host, uri.port).request(proxy_request,request.body.read) do|proxy_response|
          chunk_count,bytes_sent = send_response( request, response, http_params, proxy_response )
        end # end request
 
        if !@control.nil? and !@cache_buffer.nil? and @control['max-age'].to_i > 0 and @cache_buffer.size > 0
          @cache_buffer.rewind
          @config.cache.put(path_with_query, http_params, @control['max-age'].to_i, @cache_buffer.read )
        end

      end
      [chunk_count, bytes_sent, status, sent_from_cache]
    end

  protected
    def send_response( http_request, http_response, http_params, proxy_response )
      status = read_status( proxy_response )

      headers = copy_headers( proxy_response )
      
      if proxy_response.header["Surrogate-Control"]
        @control = {}
        proxy_response.header["Surrogate-Control"].split(',').each do |pair|
          k,v = pair.strip.split('=')
          @control[k] = v
        end
        if @control['max-age'].to_i > 0
          @cache_buffer = StringIO.new
        end
      end

      # build the initial HTTP HEAD response
      header = Mongrel::Const::STATUS_FORMAT % [status, Mongrel::HTTP_STATUS_CODES[status]]
      headers.each {|k,v| header << "#{k}: #{v}\r\n" }

      if status >= 500 or !@config.enable_esi_processor?( proxy_response )
        http_response.write header 
        http_response.write "\r\n" 
        proxy_direct( http_response, proxy_response )
      elsif http_request.params["HTTP_VERSION"] == "HTTP/1.0" and http_request.params["REQUEST_METHOD"] != "HEAD"
        body = proxy_response.read_body
        buffer = StringIO.new
        send_esi_buffered( buffer, http_request, http_params, body )
        buffer.rewind
        header << "Content-Length: #{buffer.size}\r\n\r\n"
        http_response.write( header )
        buffer = buffer.read # replace with in memory
        http_response.write( buffer )
        @cache_buffer << header if @cache_buffer
        @cache_buffer << buffer if @cache_buffer
        [0,buffer.size]
      else
        # write current http header into the cache
        @cache_buffer << header if @cache_buffer
        header << "Transfer-Encoding: chunked\r\n\r\n" # don't save this to the cache
        # now we don't know the content-length yet, but we save a spot for it
        @cache_buffer << "Content-Length: \r\n\r\n" if @cache_buffer
        http_response.write( header )
        return [0,0] if http_request.params["REQUEST_METHOD"] == "HEAD"
        proxy_filter_esi( http_request, http_response, http_params, proxy_response )
      end
    end

    def proxy_direct( http_response, proxy_response )
      bytes_sent = 0
      proxy_response.read_body do|fragment|
        http_response.write fragment
        bytes_sent += fragment.size
      end
      http_response.done = true if http_response.respond_to?(:done)
      return [0,bytes_sent]
    end

    def proxy_filter_esi( http_request, http_response, http_params, proxy_response )
      processor = Processor.new( @config, @router, @cache_buffer )
      processor.send_body( http_request, http_params, http_response, proxy_response )
    end
    
    def send_esi_buffered( response, request, http_params, buffer )
      parser = ESI::Parser.new( response, @router, @config.cache, 3 )
      parser.prepare( request.params, http_params )
      parser.process buffer
      parser.finish
      response.done = true if response.respond_to?(:done)
    end

    def read_status(response)
      Net::HTTPResponse::CODE_TO_OBJ.select { |k,v| v == response.class }.first[0].to_i rescue 500
    end

    def http_params(params)
      updated_params = {}
      params.each do|k,v|
        if k.match(/HTTP/i)
          k = k.split('_').collect { |t| t.capitalize }.join('-')
          if k[0,5] =='Http-'
            k[0,5] = ''
            updated_params[k] = v
          end
        end
      end
      updated_params
    end

    def copy_headers(response)
      headers = {}
      response.to_hash.each do |k,v|
        # for Set-Cookie we need to split on ,
        # some edge cases with , since things like expires might be a date with , in them.
        k = k.split(/-/).map{|s| s.capitalize }.join('-')

        next if k.match(/Content-Length|Surrogate-Control|Server|Connection|Status/i)

        headers[k] = v
      end
      headers["Server"] = SERVER
      headers
    end

  end # Handler

end # ESI
