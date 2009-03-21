# Copyright (c) 2008 Todd A. Fisher
# see LICENSE
require 'digest/sha1'
require 'thread'
require 'ostruct'
require 'esi/logger'

module ESI

  # Represents part of the cached page, typically an <esi:include 
  class Fragment
    attr_accessor :body, :max_age, :uri
    alias read_body body

    def initialize(uri,max_age,body)
      @uri = uri
      @max_age = Time.now.to_i + max_age.to_i
      @body = body
    end

    # make a copy of the object, necessary for thread safety
    def dup
      Fragment.new( @uri, @max_age, @body )
    end

    # determine if the fragment is still valid, given the max age associated when the object was created
    def valid?
      (Time.now.to_i < @max_age)
    end

  end
  

  # cache interface
  #
  #  all caches store Fragments
  #
  #  get - uri,params => Fragment
  #
  #  cached? - uri,params => boolean
  # 
  #  put - uri,params, max_age, body => nil
  #
  #  sweep! - tells the cache to expire anything that needs expiring
  # 
  #  keys - is an optional method for iterating over all keys, may not be exposed by all cache backends
  #
  #  delete - key remove the key from the cache
  #
  # Base Cache object
  class Cache

		def initialize
		end

  protected
    def cache_key( uri, params )
      http_x_requested_with = params['HTTP_X_REQUESTED_WITH'] || params["X-Requested-With"]
      key = Digest::SHA1.hexdigest("#{uri}-#{http_x_requested_with}")
      key
    end
    
  end
  
  #
  # A memcache cache store.  Uses the memcached ruby client, see => http://seattlerb.rubyforge.org/memcache-client/
  # and http://www.danga.com/memcached/
  #
  # There are few issues to consider about providing a memcached backed.
  #
  # First, there's no good way to iterate over all the keys within memcached and doing so is problematic beyound the impelmentation
  # more details can be found here => http://lists.danga.com/pipermail/memcached/2007-February/003610.html
  #
  # Okay, so now what?  Well we still have options:
  #  - We could try Tugela Cache => http://meta.wikimedia.org/wiki/Tugela_Cache
  #  - This looks promising => http://www.marcworrell.com/article-500-en.htmlhttp://www.marcworrell.com/article-500-en.html
  #  - We could also store the keys in the ruby process or alternatively look in INVALIDATION-WITH-MEMCACHED
  #
  # We can't support advanced selector with memcached backend
  #
  # Configuring:
  #
  #  config.cache do|c|
  #    c.memcached do|mc|
  #      mc.servers = ['localhost:11211']
  #      mc.debug = false
  #      mc.namespace = 'mesi'
  #      mc.readonly = false
  #    end
  #    c.ttl = 600
  #  end
  #
  class MemcachedCache < Cache
    require 'rubygems'
    begin
      require 'memcached'
    rescue LoadError => e
      puts "using memcache client: #{e.message}"
      require 'memcache'
    end
    include ESI::Log

    def initialize( options )
      super()
      options = options.marshal_dump
      options.merge!( :multithread => true )
      puts "Using memcache with options => #{options.inspect}"
      @cache = MemCache.new options
      puts "Using memcache servers at #{options[:servers].inspect}"
      @cache.servers = options[:servers]
    end

    def cached?( uri, params )
      fragment = get(uri,params)
      fragment and fragment.valid?
    rescue Object => e # never raise an exception from this method
      STDERR.puts "error in #{__FILE__}:#{__LINE__}"
      false
    end

    def get( uri, params )
      fragment = @cache.get(cache_key(uri,params))
      fragment.dup if fragment and fragment.respond_to?(:dup)
    end
 
    def put( uri, params, max_age, body )
      fragment = Fragment.new(uri,max_age,body)
      key = cache_key(uri,params)
      @cache.add( key, fragment, fragment.max_age )
    rescue Object => e
      STDERR.puts "error in #{__FILE__}:#{__LINE__}"
			log_error e.message
    end

		# run through the cache and dump anything that has expired
		def sweep!
      # TODO: not really a memcached equivalent??
		end

    def keys(&block)
      # TODO: can't implement this method directly with memcached, unless we introduce another key
      # and increase the data, but it is possible...
    end

    def delete( key )
      delete_unlocked
    end
    
    def delete_unlocked( key )
      @cache.delete(key)
    end
 
    def sweep_unlocked!
    end

  end

  #
  # A ruby thread safe cache, stores cached fragments in the current ruby process memory
  #
  # A hash table indexed by cache_key of Fragments.
  # the cache is made thread safe if the external invalidator is active otherwise the Mutex is a no op
  #
  # Default cache.
  class RubyCache < Cache

    def initialize( options = {} )
      super()
      @semaphore = Mutex.new
      @cache = {}
    end

    def cached?( uri, params )
      key = cache_key(uri,params)
      fragment = @semaphore.synchronize { @cache[key] }
      fragment and fragment.valid?
    end

    def get( uri, params )
      key = cache_key(uri,params)
      fragment = @semaphore.synchronize { @cache[key] }
      fragment.dup if fragment and fragment.valid? and fragment.respond_to?(:dup)
    end
 
    def put( uri, params, max_age, body )
      key = cache_key(uri,params)
      @semaphore.synchronize do
        @cache[key] = Fragment.new(uri,max_age,body)
        sweep_unlocked!
      end
    end

		# run through the cache and dump anything that has expired
    def sweep!
      @semaphore.synchronize { sweep_unlocked! }
    end

    def keys(&block)
      @semaphore.synchronize do
        @cache.each do|key,data|
          yield key, data
        end
      end
    end

    def delete( key )
      @semaphore.synchronize { @cache.delete(key) }
    end
 
    def delete_unlocked( key )
      @cache.delete(key)
    end
 
    def sweep_unlocked!
      @cache.reject! {|k,v| !v.valid? }
    end

  end

end
