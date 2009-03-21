Merb::Router.prepare do |r|
  r.match('/frag1').to(:controller => 'frag1', :action =>'index')
end

class Frag1 < Merb::Controller
  def index
    sleep 0.05
    "Y"*1024
  end
end

Merb::Config.use { |c|
  c[:framework]           = {},
  c[:session_store]       = 'none',
  c[:exception_details]   = true
}
