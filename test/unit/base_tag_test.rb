require File.join(File.dirname(__FILE__),'help.rb')

class BaseTagTest < Test::Unit::TestCase

  def tag_with_request( http_params = {} )
    ESI::Tag::Base.new(@test_router,http_params, {},'test',{},{})
  end

  def test_prepare_url_vars
    # test happy path
    value = 'foo'
    url = tag_with_request({'HTTP_COOKIE' => "type=#{value}"}).prepare_url_vars( "http://www.example.com/$(HTTP_COOKIE{type})/hello.gif" )
    assert_equal "http://www.example.com/#{value}/hello.gif", url
    # test empty cookie value
    value = ''
    url = tag_with_request({'HTTP_COOKIE' => "type=#{value}"}).prepare_url_vars( "http://www.example.com/$(HTTP_COOKIE{type})/hello.gif" )
    assert_equal "http://www.example.com/#{value}/hello.gif", url
    # test no cookie http key
    url = tag_with_request.prepare_url_vars( "http://www.example.com/$(HTTP_COOKIE{type})/hello.gif")
    assert_equal "http://www.example.com//hello.gif", url
    
    # test a funky variable that's not supported
    url = tag_with_request.prepare_url_vars( "http://www.example.com/$(H_COOKIE{type})/hello.gif")
    assert_equal "http://www.example.com//hello.gif", url
   
    # test a syntax error
    url = tag_with_request.prepare_url_vars( "http://www.example.com/$(H_COOKIE{type}/hello.gif")
    assert_equal "http://www.example.com/$(H_COOKIE{type}/hello.gif", url

    # test multiple variables in the URL
    v1 = 'foo'
    v2 = 'bar'
    url = tag_with_request({'HTTP_COOKIE' => "type=#{v1};type2=#{v2}"}).prepare_url_vars( "http://www.example.com/$(HTTP_COOKIE{type})/$(HTTP_COOKIE{type2}).gif")
    assert_equal "http://www.example.com/#{v1}/#{v2}.gif", url
  end

  def test_bug_fix_for_complex_url
    url = "/content/modules/head/header_contents?pma_module_id=head%2Fheader_contents&cache_ttl=600&display_signin=true&pma_request=true&view=header_contents&display_search=true&q_module_wrap=block&b2bid=$(HTTP_COOKIE{b2bid})"
    assert_match /b2b_expected/, tag_with_request({"HTTP_COOKIE" => "b2bid=b2b_expected;edn=reg_expected"}).prepare_url_vars(url)
    url = "/registration/modules/mini_dashboard/show?cache_ttl=600&pma_module_id=mini_dashboard%2Fshow&q_module_wrap=block&pma_request=true&edn=$(HTTP_COOKIE{edn})"
    assert_match /reg_expected/, tag_with_request({"HTTP_COOKIE" => "b2bid=b2b_expected;edn=reg_expected"}).prepare_url_vars(url)
  end

end
