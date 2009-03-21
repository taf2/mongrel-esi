require "#{File.dirname(__FILE__)}/help"

class BasicTest < Test::Unit::TestCase

  def test_simple_initalize
    assert_nothing_raised do
      dispatcher = ESI::Dispatcher.new(
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
    end
  end

  def test_router
    router = ESI::Router.new( [{:host => '127.0.0.1', :port => '9999', :match_url => '^\/(content|samples|extra|get_test).*'},
               {:host => '127.0.0.1', :port => '9998', :match_url => 'default'}] )
    assert_equal "http://127.0.0.1:9999/content/foo.html", router.url_for("/content/foo.html")
    assert_equal "http://127.0.0.1:9998/esi_mixed_content.html", router.url_for("/esi_mixed_content.html")
  end

end
