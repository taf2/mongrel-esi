require File.join(File.dirname(__FILE__),'help.rb')

class IncludeRequestTest < Test::Unit::TestCase
  include TestServer

  def request(path,alt=nil,headers={})
    ir = ESI::Tag::Include::Request.new(headers)
    buffer = ""
    status = 0
    info = nil
    alt = "http://127.0.0.1:9999#{alt}" if alt
    ir.request("http://127.0.0.1:9999#{path}",0.5,alt) do|s,r|
      if s
        buffer = r.read_body
        status = 1
      else
        info = r.message
        buffer = r.response.read_body if r.response
      end
    end
    [buffer,info,status]
  end

  def test_request_features
    # success
    ri = request('/test/success')
    assert_equal 1, ri[2], "Request failed\n#{ri[0]}"
    assert_equal %Q(<div>hello there world</div>), ri[0], "Request failed"
    
    # redirect
    ri = request('/test/redirect')
    assert_equal 1, ri[2], "Request failed\n#{ri[0]}"
    assert_equal %Q(<div>hello there world</div>), ri[0], "Request failed"
  
    # error_alt
    ri = request('/test/error','/test/success')
    assert_equal 1, ri[2], "Request failed\n#{ri[0]}"
    assert_equal %Q(<div>hello there world</div>), ri[0], "Request failed"
  
    # error_no_alt
    ri = request('/test/error')
    assert_equal 0, ri[2], "Request should have failed\n#{ri[0]}"
    
    # not so happy paths
    # error_error_alt
    ri = request('/test/error','/test/error')
    assert_equal 0, ri[2], "Request should have failed\n#{ri[0]}"
    
    # redirect_failed_to_alt
    ri = request('/test/redirect_to_error','/test/redirect_to_error')
    assert_equal 0, ri[2], "Request should have failed\n#{ri[0]}"
  
    # request_timesout
    ri = request('/test/timeout')
    assert_equal 0, ri[2], "Request should have failed\n#{ri[0]}"

    # headers_forward
    ri = request('/test/headers',nil,{'Headers1' => 'value1', 'Headers2' => 'value2'})
    assert_equal 1, ri[2], "Request should not have failed\n#{ri[0]}"
  end
  
end
