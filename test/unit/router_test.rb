require File.join(File.dirname(__FILE__),'help.rb')
require 'esi/router'

class RouterTest < Test::Unit::TestCase
  
  def router
    ESI::Router.new(
    [{:host => '127.0.0.1', :port => '8504', :match_url => '(^\/(images\/sorry|articles|privacy-policy|terms-of-service|about|site-map|contact-us|help|store).*|^\/(\?.*)?$)'},
     {:host => '127.0.0.1', :port => '8509', :match_url => '^\/(test).*|^$'},
     {:host => '127.0.0.1', :port => '8502', :match_url => 'default'}] )
  end


  def test_default_route
    url = router.url_for( "/foo" )
    assert_equal( 'http://127.0.0.1:8502/foo', url )
  end

  def test_slash_landing_with_query
    url = router.url_for( "/?hello" )
    assert_equal( 'http://127.0.0.1:8504/?hello', url )
  end

  def test_test_page
    url = router.url_for( "/test" )
    assert_equal( 'http://127.0.0.1:8509/test', url )
  end

  def test_pass_url_with_scheme
    assert_equal "http://example.com", router.url_for("http://example.com")
    assert_equal "http://www.example.com", router.url_for("http://www.example.com")
  end

end
