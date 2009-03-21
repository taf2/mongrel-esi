Merb::Router.prepare do |r|
  r.match('/frag3').to(:controller => 'frag3', :action =>'index')
end

class Frag3 < Merb::Controller
  def index
    "<p>Hello there user</p>"
  end
end

Merb::Config.use { |c|
  c[:framework]           = {},
  c[:session_store]       = 'none',
  c[:exception_details]   = true
}
