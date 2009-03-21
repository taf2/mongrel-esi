Merb::Router.prepare do |r|
  r.match('/frag2').to(:controller => 'frag2', :action =>'index')
end

class Frag2 < Merb::Controller
  def index
    "Y"*4096
  end
end

Merb::Config.use { |c|
  c[:framework]           = {},
  c[:session_store]       = 'none',
  c[:exception_details]   = true
}
