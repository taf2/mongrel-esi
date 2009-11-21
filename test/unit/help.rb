$:.unshift File.join(File.dirname(__FILE__), "..", "..", "lib")
$:.unshift File.join(File.dirname(__FILE__), "..", "..", "ext")
require 'test/unit'
require 'rubygems'
require 'mongrel'
require 'mocha'

ENV["test"] = 'true'
require 'esi/cache'
require 'esi/router'
require 'esi/esi'
require 'esi/tag/base'
require 'esi/tag/include'
require 'esi/tag/attempt'
require 'esi/tag/except'
require 'esi/tag/try'
require 'esi/tag/invalidate'

require 'webrick'
class ::WEBrick::HTTPServer ; def access_log(config, req, res) ; end ; end
class ::WEBrick::BasicLog ; def log(level, data) ; end ; end

module TestServer
  def setup
 
    @test_router = ESI::Router.new([{:host => '127.0.0.1', :port => '9999', :match_url => 'default'}])

    if defined?($test_server_running)
      setup_extra if self.respond_to?(:setup_extra)
      return
    end
    $test_server_running = true
    @server = WEBrick::HTTPServer.new( :Port => 9999 )

    # setup test server (simulates exact target)
    @server.mount_proc("/test/error") do|req,res|
      raise "fail"
    end
    @server.mount_proc("/test/redirect") do|req,res|
      res.set_redirect(WEBrick::HTTPStatus::MovedPermanently,"/test/success")
    end
    @server.mount_proc("/test/redirect_to_error") do|req,res|
      res.set_redirect(WEBrick::HTTPStatus::MovedPermanently,"/test/error")
    end
    @server.mount_proc("/test/success") do|req,res|
      id = req.query["id"]
      if id
        res.body = "<div id='#{id}'>id string</div>"
      else
        res.body = "<div>hello there world</div>"
      end
      res['Content-Type'] = "text/html"
    end
    @server.mount_proc("/test/timeout") do|req,res|
      sleep 0.8 # needs to be high for slower machines, like my ppc mac
      res.body = "<div>We won't get this for a few seconds</div>"
      res['Content-Type'] = "text/html"
    end
    @server.mount_proc("/test/headers") do|req,res|
      res.body = "<div>hello there world</div>"
      res['Content-Type'] = "text/html"
      begin
        assert_equal ['value1'], req.header['headers1']
        assert_equal ['value2'], req.header['headers2']
      rescue Object => e
        puts e.message
        raise e
      end
    end

    # start up the server in a background thread
    @thread = Thread.new(@server) do|server|
      server.start
    end
    setup_extra if self.respond_to?(:setup_extra)
    at_exit do
      @server.shutdown
      @thread.join
    end
  end
end
