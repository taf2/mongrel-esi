# Copyright (c) 2008 Todd A. Fisher
# see LICENSE
require 'ostruct'
require 'esi/router'

module ESI
  # This file provides configuration options to mongrel-esi
  # Mongrel ESI is a proxy caching server with limited load balancing capablities
  #
  #  ESI::Config.define(listeners) do|config|
  #  
  #    # define the caching rules globally for all routes, defaults to ruby
  #    config.cache do|c|
  #      c.memcached do|mc|
  #        mc.servers = ['localhost:11211']  # memcahed servers
  #        mc.namespace = 'mesi'  # namespace for cache storage
  #      end
  #      c.ttl = 600 # default fragment time to live, when <esi:include does not include the max-age attribute
  #    end
  #
  #    # define rules for when to enable esi processing globally for all routes
  #    # using content type it is more flexible, but sometimes you will want to be
  #    # explicit about when to enable esi processing. For those cases, enable_for_surrogate_only will
  #    # require the presense of the Surrogate-Control header to contain the content="ESI/1.0" line.
  #    # see [http://www.w3.org/TR/edge-arch Edge Arch] for details.
  #    config.esi do|c|
  #      c.allowed_content_types = ['text/plain', 'text/html']
  #      #c.enable_for_surrogate_only = true # default is false
  #    end
  #
  #    # define request path routing rules, these rules match against request path to select a specific server
  #    config.routes do|s|
  #      #s.match( /content/ ) do|r|
  #      #  r.servers = ['127.0.0.1:4000']
  #      #end
  #      s.default do|r|
  #        r.servers = ['127.0.0.1:3000']
  #      end
  #    end
  #
  #  end
  class Config

    attr_reader :config
    
    def initialize(options)
      @config = options
    end

    # access configuration values
    def [](key)
      @config[key]
    end

    def enable_esi_processor?( headers )
      # check for surrogate control configuration
      # check for matching content type
      # if both are set it surrogate takes presendence 
      use_esi = false
      allowed_content_types = @config[:allowed_content_types]

      if allowed_content_types and headers["content-type"] and allowed_content_types.respond_to?(:detect)
        use_esi = allowed_content_types.detect do |type|
          headers["content-type"].match( type )
        end
        use_esi = true if use_esi
      end

      if @config[:enable_for_surrogate_only]
        use_esi = headers["surrogate-control"] and /ESI/.match(headers["surrogate-control"])
      end

      use_esi
    end

    class CacheConfig
      attr_reader :options
      def initialize
        @memcached = false
        @options = OpenStruct.new({}) 
      end

      def memcached
        @memcached = true
        yield @options
      end

      def memcached?
        @memcached
      end

      def locked
        !@memcached
      end

      def ttl=( ttl )
        @options.ttl = ttl
      end

    end
 
    # returns the cache object as given in the config/esi.yml
    # cache: key, or defaults to ruby as in uses this process
    # the options allowed are ruby and memcache
    def cache
      if block_given?
        # allow this method to be called in config scripts
        cache_options = CacheConfig.new
        yield cache_options
        if cache_options.memcached?
          @config[:cache] = 'memcached'
        else
          @config[:cache] = 'ruby'
        end
        @config[:cache_options] = cache_options.options
      else
        cache_type = @config[:cache]
        options = @config[:cache_options]
        # always return the same cache object, per process
        $cache ||= case cache_type
        when 'ruby'
          ESI::RubyCache.new(options)
        when 'memcached'
          ESI::MemcachedCache.new(options)
        else
          raise "Unsupported cache"
        end
      end
    end

    def esi
      options = OpenStruct.new({})
      yield options
      @config[:allowed_content_types] = options.allowed_content_types if options.allowed_content_types
      @config[:enable_for_surrogate_only] = options.enable_for_surrogate_only if options.enable_for_surrogate_only
      @config[:chunk_size] = options.chunk_size if options.chunk_size
      @config[:max_depth] = options.max_depth if options.max_depth
    end

    def router
      ESI::Router.new( @config[:routing] )
    end
 
    class ConfigRouter
      attr_accessor :servers
      attr_reader :routes

      def initialize
        @routes = []
        @servers = []
      end

      def match( expr )
        yield self
        @routes << { :host => @servers.first.split(':').first, 
                     :port => @servers.last.split(':').last,
                     :match_url => expr }
      end

      def default
        yield self
        @routes << { :host => @servers.first.split(':').first, 
                     :port => @servers.last.split(':').last,
                     :match_url => 'default' }
      end

    end

    def routes
      config_router = ConfigRouter.new
      yield config_router
      @config[:routing] = config_router.routes
    end

    def self.define( listeners )
      listeners.each do|host,server|
        esi_handlers = server.classifier.handler_map.select do|uri,handler|
          handler.first.class == ESI::Dispatcher
        end
        config = esi_handlers.first.last.first.config
        yield config
      end
    end

  end    
end

