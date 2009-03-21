# This file provides configuration options to mongrel-esi
# Mongrel ESI is a proxy caching server with limited load balancing capablities

ESI::Config.define(listeners) do|config|

  # define the caching rules globally for all routes, defaults to ruby
  config.cache do|c|
    #c.memcached do|mc|
    #  mc.servers = ['localhost:11211']
    #  mc.debug = false
    #  mc.namespace = 'mesi'
    #  mc.readonly = false
    #end
    c.ttl = 600
  end

  # define rules for when to enable esi processing globally for all routes
  config.esi do|c|
    c.allowed_content_types = ['text/plain', 'text/html']
    #c.enable_for_surrogate_only = true # default is false
  end

  # define request path routing rules
  config.routes do|s|
    s.match( /frag1/ ) {|r| r.servers = ['127.0.0.1:4001'] }
    s.match( /frag2/ ) {|r| r.servers = ['127.0.0.1:4002'] }
    s.match( /frag3/ ) {|r| r.servers = ['127.0.0.1:4003'] }
    s.match( /frag4/ ) {|r| r.servers = ['127.0.0.1:4004'] }
    s.default {|r| r.servers = ['127.0.0.1:4000'] }
  end

end
