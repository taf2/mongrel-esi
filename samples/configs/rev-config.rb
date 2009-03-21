# This is the configuration file used by revolution during local development.
# It supports features like servering static assets from multiple backend rails applications
# Using MultipleDirHandler, it will also look in specific gems for assets
require 'multi_dirhandler'
require 'rubygems'

asset_paths = [
  "/home/taf2/portal-all/trunk/",
  "/home/taf2/portal-all/content/trunk/",
  "/home/taf2/portal-all/core/rhg_ui/trunk/vendor/plugins/rhg_ui/",
  "/home/taf2/portal-all/core/rhg_rte/trunk/vendor/plugins/rhg_rte/",
  "/home/taf2/portal-all/fabric/trunk/",
  "/home/taf2/rhg/applications/ruby/symptom_checker/trunk/",
  "/home/taf2/portal-all/rhg-library/trunk/",
  "/home/taf2/portal-all/insurance/trunk/",
  "/home/taf2/portal-all/search/trunk/" ]
asset_gems = ['rhg_ui','rhg_rte']

puts "Loading gems from => #{Gem.path}..."
asset_paths += asset_gems.map do |gem|
  begin
    path = File.join(Gem.path, 'gems', Gem.cache.search(gem).last.full_name)
    puts "#{gem} => #{path}"
    path
  rescue
    puts "Skipping #{gem}, check that the gem is installed..."
  end
end
asset_gems.flatten!

log "\n** Loading docroots..."
routing = {"javascripts"=>[],"stylesheets"=>[],"images"=>[],"flash"=>[]}
routing.each do|route,r|
  routing[route] = asset_paths.collect { |root| "#{root}/public/#{route}".squeeze("/") }
end

routing.each do |route|
  log " - #{route[0]}"
  route[1].each do |path|
    log "   #{path}"
  end
end


uri "/javascripts", :handler => MultiDirHandler.new(routing["javascripts"], :cwd => defaults[:cwd])
uri "/stylesheets", :handler => MultiDirHandler.new(routing["stylesheets"], :cwd => defaults[:cwd])
uri "/images", :handler => MultiDirHandler.new(routing["images"], :cwd => defaults[:cwd])
uri "/flash", :handler => MultiDirHandler.new(routing["flash"], :cwd => defaults[:cwd])

# Setup the ESI Handler configuration to respond to all requests made to "/*"
ESI::Config.define(listeners) do|config|

  # define the caching rules globally for all routes, defaults to ruby
  config.cache do|c|
    c.memcached do|mc|
      mc.servers = ['localhost:11211']
      mc.debug = false
      mc.namespace = 'mesi'
      mc.readonly = false
    end
    c.ttl = 600
  end

  # define rules for when to enable esi processing globally for all routes
  config.esi do|c|
    c.allowed_content_types = ['text/plain', 'text/html']
    #c.enable_for_surrogate_only = true # default is false
    c.chunk_size = 4096
    c.max_depth = 3
  end

  # define request path routing rules
  config.routes do|s|
    s.match( /^\/(images\/sorry|depression|home|content|healthy-living|conditions|learn-from-others|articles|assessments|quizzes|privacy-policy|terms-of-service|about|site-map|contact-us|help|store).*|^\/(\?.*)?$/ ) do|r|
      r.servers = ['127.0.0.1:8504']
    end
    s.match( /^\/(live-better).*|^$/ ) do|r|
      r.servers = ['127.0.0.1:8502']
    end
    s.match( /^\/(test).*|^$/ ) do |r|
      r.servers = ['127.0.0.1:8509']
    end
    s.match( /^\/(fabric|pages|doctors).*/ ) do |r|
      r.servers = ['127.0.0.1:8505']
    end
    s.match( /^\/(search|SearchService).*/ ) do|r|
      r.servers = ['127.0.0.1:8511']
    end
    s.match( /^\/(family).*/ ) do |r|
      r.servers = ['127.0.0.1:8513']
    end
    s.match( /^\/(symptom).*/ ) do |r|
      r.servers = ['127.0.0.1:8514']
    end
    s.match( /^\/(groups|group).*/ ) do |r|
      r.servers = ['127.0.0.1:8510']
    end
    s.match( /^\/(newsletters).*/ ) do |r|
      r.servers = ['127.0.0.1:8515']
    end
    s.default do|r|
      r.servers = ['127.0.0.1:8502']
    end
  end

end
