require 'test/unit'
require File.join(File.dirname(__FILE__), 'help')

class GetTest < Test::Unit::TestCase
  include TestServerMethods

  def setup
    siphon_setup
  end

  def resolve_path(path)
    "http://127.0.0.1:#{@siphon_port}#{path}"
  end

  def test_simple_hello
    res = hit([resolve_path("/hello")])
    assert_equal "<html><head></head><body>Request: /hello\n</body></html>\n", res.first
    check_status( res, String )
  end

  def test_sendfile
    res = hit([resolve_path("/response.h")])
    assert_equal File.read(File.join(File.dirname(__FILE__),'..','response.h')), res.first
    check_status( res, String )
  end

  def test_headers
    res = Net::HTTP.start('127.0.0.1', 9997).request(Net::HTTP::Get.new('/'))
    headers = res.to_hash
    assert_equal Net::HTTPOK, res.class
    assert_equal  ["Keep-Alive"], headers["connection"]
    assert_equal  ["text/plain"], headers["content-type"]
    assert_equal  ["3"], headers["content-length"]
  end

  def test_proxy_small
    res = hit([resolve_path("/")])
    assert_equal( "GET", res.first )
    check_status( res, String )
  end

  def test_proxy_large
    res = Net::HTTP.start('127.0.0.1', 9997).request(Net::HTTP::Get.new('/slow'))
    headers = res.to_hash
    assert_equal Net::HTTPOK, res.class
    assert_equal "x" * 10240, res.body
  end
  
  def test_proxy_slow_large
    res = Net::HTTP.start('127.0.0.1', 9997).request(Net::HTTP::Get.new('/delay'))
    headers = res.to_hash
    assert_equal Net::HTTPOK, res.class
    assert_equal "x" * 10240 * 2, res.body
  end

  def test_mime_types
    res = Net::HTTP.start('127.0.0.1', 9997).request(Net::HTTP::Get.new('/test/fake.gif'))
    headers = res.to_hash
    assert_equal Net::HTTPOK, res.class
    assert_equal  ["image/gif"], headers["content-type"]
    assert_equal "not really a gif\n", res.body
  end

end
