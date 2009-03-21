Merb::Router.prepare do |r|
  r.match('/frag4').to(:controller => 'frag4', :action =>'index')
end

class Frag4 < Merb::Controller
  def index
    "Y"*4096
  end
end

Merb::Config.use { |c|
  c[:framework]           = {},
  c[:session_store]       = 'none',
  c[:exception_details]   = true
}
