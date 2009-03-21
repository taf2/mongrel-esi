require "#{File.dirname(__FILE__)}/help"
require 'esi/cache'

class CacheTest < Test::Unit::TestCase

  def test_can_cache
    cache = ESI::RubyCache.new
    value = "test"
    cache.put( "key", {}, 10, value )
    fragment = cache.get("key", {} )
    assert_equal value, fragment.body
    assert fragment.valid?
  end

  def test_can_cache_with_invalidator
    cache = ESI::RubyCache.new( :locked => true )
    value = "test"
    cache.put( "key", {}, 10, value )
    fragment = cache.get("key", {} )
    assert_equal value, fragment.body
    assert fragment.valid?
  end

=begin
	# XXX: setup a test server for memcache testing
	def test_memcached
    cache = ESI::MemcachedCache.new( {'servers' => 'localhost:11211', :namespace => "mesi" } )
    value = "test"
    cache.put( "key", {}, 10, value )
    fragment = cache.get("key", {} )
		puts fragment.inspect
    assert_equal value, fragment.body
    assert fragment.valid?
	end
=end

end
