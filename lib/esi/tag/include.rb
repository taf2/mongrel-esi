# Copyright (c) 2008 Todd A. Fisher
# see LICENSE
#
# The esi:include tag allows markup to be included from another source URL within the current document.
#
# <esi:inlcude src="/some-markup"/>
#
# This has a similar effect to including an iframe, etc. the request happens on the server side instead of the client side.
# Also, the resulting DOM is shared unlike an iframe.
#
require 'uri'
require 'net/http'
require 'esi/parser'

module ESI
  module Tag
    class Include < Base
      #
      #
      #  ir = Request.new( {'header1'=>'value1'} )
      #
      #  ir.request( '/fragment' ) do|status,response|
      #     if status 
      #         response.read_body do|str|
      #         end
      #     else
      #         # error case
      #     end
      #  end
      #
      class Request
        class Error
          attr_reader :message, :response
          def initialize(msg,response)
            @message = msg
            @response = response
          end
        end
        attr_reader :exception, :overflow_index # TODO

        def initialize(forward_headers)
          @headers = forward_headers
        end

        def request(url, timeout = 1, alt_failover=nil, follow_limit=3)
          uri = URI.parse(url)
          Net::HTTP.start(uri.host, uri.port) do|http|
            http.read_timeout = timeout if timeout and timeout > 0
            rp = uri.query ? "#{uri.path}?#{uri.query}" : uri.path
            http.request_get( rp, @headers ) do|response|
              case response
              when Net::HTTPSuccess
                yield true, response, url
              when Net::HTTPRedirection
                ir = Request.new(@headers)
                ir.request(response['location'], timeout, alt_failover, follow_limit - 1) do|s,r|
                  yield s, r, response['location']
                end
              else
                if alt_failover
                  ir = Request.new(@headers)
                  ir.request(alt_failover, timeout, nil, follow_limit) do|s,r|
                    yield s, r, alt_failover
                  end
                else
                  yield false, Error.new("Failed to request fragment: #{uri.scheme}://#{uri.host}:#{uri.port}#{uri.path}", response), url
                end
              end
            end
          end
        rescue Timeout::Error => e
          yield false, Error.new("Failed to request fragment: #{uri.scheme}://#{uri.host}:#{uri.port}#{uri.path}, timeout error: #{e.message}", nil), url
        end

      end

      attr_accessor :depth, :max_depth

      def initialize(uri,headers,http_params,name,attrs,cache)
        super
        @depth = 0
        @max_depth = 3
      end

      def parse_fragment?
        @depth <= @max_depth
      end

      def close( output, options = {} )
        super(output)
        @output = output

        raise_on_error = options[:raise] || false # default to false

        src = @router.url_for(prepare_url_vars(@attributes["src"]))
        alt = @attributes['alt']
        alt = @router.url_for(prepare_url_vars(alt)) if alt

        prepare_parser

        if @cache.cached?( src, @http_params )
          send_from_cache( src )
        else
          send_from_origin( src, alt, raise_on_error )
        end

      end

    protected
      def prepare_parser
        if parse_fragment?
          @parser = ESI::Parser.new( @output, @router, @cache, @max_depth )
          @parser.prepare( @headers, @http_params )
          @parser.depth = (@depth+1) # increment the depth
        end
      end

      def send_from_cache( src )
        cached_fragment = @cache.get( src, @headers ).body
        #log_request "C"

        if parse_fragment? and cached_fragment.match(/<esi:/)
          @parser.process cached_fragment
          @parser.finish
        else
          @output << cached_fragment 
        end

      end

      def send_from_origin( src, alt, raise_on_error )
        #log_request "R"
        Request.new(@http_params).request(src, @attributes['timeout'].to_i, alt ) do|status,response,url|
          if status
            process_successful_response( url, status, response )
          else
            # error/ check if the include has an onerror specifier
            return if @attributes['onerror'] == 'continue'
            # response is a Request::Error
            raise response.message if raise_on_error
            # stop processing and return the error object
            return response
          end
        end
      end

      def process_successful_response( url, status, response )
        # NOTE: it's important that we cache the unprocessed markup, because we need to 
        # reprocess the esi:include vars even for cached content, this way we can have cached content
        # with HTTP_COOKIE vars and avoid re-requesting content
        cache_buffer = ""
        if parse_fragment?
          response.read_body do|s|
            cache_buffer << s
          end
          if cache_buffer.match(/<esi:/)
            @parser.process cache_buffer
            @parser.finish
          else
            @output << cache_buffer
          end
        else
          response.read_body do|s|
            cache_buffer << s
          end
          @output << cache_buffer
        end

        request_uri = url

        cache_ttl = (@attributes['max-age']||600) # defaults to 600... maybe should have this be configurable?
        if cache_ttl.respond_to?(:match) and cache_ttl.match(/\+/)
          total=0
          cache_ttl.split('+').each {|comp| total+=comp.to_i}
          cache_ttl = total
        else
          cache_ttl = cache_ttl.to_i
        end

        @cache.put(request_uri, @http_params, cache_ttl, cache_buffer )
        #log_request "R #{src} #{Time.now - timer}\n"
      end


    end

  end
end
