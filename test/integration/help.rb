# modified version from mongrel
require 'rubygems'
#  This code is moving into integration test folder
$:.unshift File.join(File.dirname(__FILE__), "..", "..", "lib")
$:.unshift File.join(File.dirname(__FILE__), "..", "..", "ext")
require 'esi/dispatcher'
require 'test/unit'
SERVER_ROOT = "#{File.dirname(__FILE__)}/../../"
ENV["test"] = "true"
DOCROOT = "#{File.dirname(__FILE__)}/docs/"

# Either takes a string to do a get request against, or a tuple of [URI, HTTP] where
# HTTP is some kind of Net::HTTP request object (POST, HEAD, etc.)
def hit(uris)
  results = []
  uris.each do |u|
    res = nil

    assert_nothing_raised do
      if u.kind_of? String
        res = Net::HTTP.get(URI.parse(u))
      else
        url = URI.parse(u[0])
        res = Net::HTTP.new(url.host, url.port).start {|h| h.request(u[1]) }
      end
    end

    assert_not_nil res, "Didn't get a response: #{u}"
    results << res
  end

  return results
end

def check_status(results, expecting)
  results.each do |res|
    assert(res.kind_of?(expecting), "Didn't get #{expecting}, got: #{res.class}")
  end
end


class MockRequest
  def initialize(params={})
    @params = params
  end
  def params
    @params
  end
end

def cached?( uri )
  $esi_dispatcher.config.cache.get( uri, {} )
end

require 'singleton'

TEST_COOKIE1 = "s_cc=true; s_sq=%5B%5BB%5D%5D; _session_id=367df8904d23ee48ddac56012b9d509f;".freeze
TEST_COOKIE2 = "rhg_gsid=83d7e46425b431c6651e2beb3e4fd9e41175970072%3A; cookies_enabled=true;".freeze
TEST_COOKIE3 = "RTOKEN=dG9kZGZAc2ltb2hlYWx0aC5jb20%3D; rhg_sa=xbSssuHwmP5rohZ0Pcu%2BmaU3bSFU%2Br1eBq4iZgTd%2BbQ%3D; edn=Z%25A16W%25E9F%25D4f%25A5%2522j%255D%25DA%2528%2585%2586; ems=%25F2%25A9%25FBlZ%2594.a%253D%250A%251F%2506%25BD%251B%25BA%25EC; av=13; s_se_sig=dG9kZGZAc2ltb2hlYWx0aC5jb20%253D; rhg_css_to_warn=1175974191515".freeze
FRAGMENT_TEST1_URI = "http://127.0.0.1:9998/fragments/test1.html".freeze
FRAGMENT_TEST2_URI = "http://127.0.0.1:9999/content/test2.html".freeze

class PostHandler < Mongrel::HttpHandler
  include Mongrel::HttpHandlerPlugin
  def process(request, response)
    response.start(200,true) do |head,out|
      head["Set-Cookie"] = TEST_COOKIE1
      head["Set-Cookie"] = TEST_COOKIE2
      head["Set-Cookie"] = TEST_COOKIE3
      out << request.body.read
    end
  end
end

class PostRedirectHandler < Mongrel::HttpHandler
  include Mongrel::HttpHandlerPlugin
  def process(request, response)
    response.start(302,true) do |head,out|
      head["Location"] = "/esi_test_content.html"
      out << %Q(<html><body>You are being <a href="/test1.html">redirected</a>.</body></html>)
    end
  end
end

class Basic404Handler < Mongrel::HttpHandler
  include Mongrel::HttpHandlerPlugin
  def process(request, response)
    response.start(404,true) do |head,out|
      head["Surrogate-Control"] = %q(max-age=0, content="ESI/1.0 ESI-INV/1.0")
      out << %q(<html><body><esi:include src='/test1.html'/></body></html>)
    end
  end
end

class Basic404HandlerWithoutHeader < Mongrel::HttpHandler
  include Mongrel::HttpHandlerPlugin
  def process(request, response)
    response.start(404,true) do |head,out|
      #head["Surrogate-Control"] = %q(max-age=0, content="ESI/1.0 ESI-INV/1.0")
      out << %q(<html><body><esi:include src='/test1.html'/></body></html>)
    end
  end
end

class Basic500Handler < Mongrel::HttpHandler
  include Mongrel::HttpHandlerPlugin
  def process(request, response)
    response.start(500,true) do |head,out|
      head["Surrogate-Control"] = %q(max-age=0, content="ESI/1.0 ESI-INV/1.0")
      out << %q(<html><body>Internal Server Error</body></html>)
    end
  end
end

class SurrogateControlHandler < Mongrel::HttpHandler
  include Mongrel::HttpHandlerPlugin
  def process(request, response)
    response.start(200,true) do |head,out|
      head["Surrogate-Control"] = request.params["HTTP_SURROGATE_CONTROL"]
      head["Content-Type"] = "text/html"
      out << File.read(File.join(File.dirname(__FILE__),'docs','esi_test_content.html'))
    end
  end
end

class AjaxCacheHandler < Mongrel::HttpHandler
  include Mongrel::HttpHandlerPlugin
  def process(request, response)
    response.start(200,true) do |head,out|
      # return hello if requested with 
      if request.params["HTTP_X_REQUESTED_WITH"] == "XMLHttpRequest"
        out << "XMLHttpRequest Request"
      else
        out << "HTTP Request"
      end
    end
  end
end

class InvalidateHandler < Mongrel::HttpHandler
  include Mongrel::HttpHandlerPlugin
  def process(request, response)
    response.start(200,true) do |head,out|
      head["Surrogate-Control"] = %q(max-age=0, content="ESI/1.0 ESI-INV/1.0")

      out << %Q(<html><body>
      <esi:invalidate output="no">
           <?xml version="1.0"?>
           <!DOCTYPE INVALIDATION SYSTEM "internal:///WCSinvalidation.dtd">
           <INVALIDATION VERSION="WCS-1.1">
             <OBJECT>
               <BASICSELECTOR URI="#{FRAGMENT_TEST1_URI}"/>
               <ACTION REMOVALTTL="0"/>
               <INFO VALUE="invalidating fragment test 1"/>
             </OBJECT>
           </INVALIDATION>
      </esi:invalidate>
      <esi:invalidate output="no">
        <?xml version="1.0"?>
        <!DOCTYPE INVALIDATION SYSTEM "internal:///WCSinvalidation.dtd">
        <INVALIDATION VERSION="WCS-1.1">
          <OBJECT>
            <BASICSELECTOR URI="#{FRAGMENT_TEST2_URI}"/>
            <ACTION REMOVALTTL="0"/>
            <INFO VALUE="invalidating fragment test 2"/>
          </OBJECT>
        </INVALIDATION>
      </esi:invalidate>
</body></html>)
    end
  end
end

$fragment_test1 = File.open("#{DOCROOT}/test1.html").read
$fragment_test2 = File.open("#{DOCROOT}/content/test2.html").read



$esi_dispatcher = ESI::Dispatcher.new(
  :host => '127.0.0.1',
  :port => 9997,
  :cwd => SERVER_ROOT,
  :log_file => 'log/test.log',
  :pid_file => 'log/test.pid',
  :daemon => false,
  :debug => true,
  :includes => ["mongrel-esi"],
  :user => nil,
  :group => nil,
  :prefix => '/',
  :config_file => nil, 
  :routing => [{:host => '127.0.0.1', :port => '9999', :match_url => '^\/(content|samples|extra|get_test).*'},
               {:host => '127.0.0.1', :port => '9998', :match_url => 'default'}],
  :cache => 'ruby',
  :cache_options => {:servers => ['localhost:11211'], :debug => false, :namespace => 'mesi', :readyonly => false},
  :allowed_content_types => ['text/plain', 'text/html'],
  :enable_for_surrogate_only => false,
  :invalidator => false
)

# allow access to the internal parser
class ESI::Handler
  attr_reader :parser
end

module ESI
  class Server
    include Singleton

    CONFIG = [
      { :host_port => { :host => '127.0.0.1', :port => 9999 },
        :handlers => [
          { :uri => '/', :handler => Mongrel::DirHandler.new(DOCROOT) },
          { :uri => '/get_test', :handler => AjaxCacheHandler.new(DOCROOT) }
        ]
      },
      { :host_port => { :host => '127.0.0.1', :port => 9998 },
        :handlers => [
          { :uri => "/", :handler => Mongrel::DirHandler.new(DOCROOT) },
          { :uri => "/fragments/", :handler => Mongrel::DirHandler.new(DOCROOT) },
          { :uri => '/post_test', :handler => PostHandler.new },
          { :uri => '/post_redirect_test', :handler => PostRedirectHandler.new },
          { :uri => '/404', :handler => Basic404Handler.new },
          { :uri => '/404-no-surrogate', :handler => Basic404HandlerWithoutHeader.new },
          { :uri => '/invalidate', :handler => InvalidateHandler.new },
          { :uri => '/surrogate-test', :handler => SurrogateControlHandler.new(DOCROOT) },
          { :uri => '/500', :handler => Basic500Handler.new }
        ]
      },
      { :host_port => { :host => '127.0.0.1', :port => 9997 },
        :handlers => [
          { :uri => "/", :handler => $esi_dispatcher }
        ]
      }
    ]

    def self.start
      ESI::Server.instance
    end

    def initialize
      @servers = CONFIG.collect do|conf|
        Mongrel::Configurator.new conf[:host_port] do
          listener do
            conf[:handlers].each do|handler|
              uri handler[:uri], :handler => handler[:handler]
            end
          end
        end
      end

      @servers.each { |server| server.run }
      at_exit do 
        @servers.each { |server| server.stop }
      end
    end
  end
end
