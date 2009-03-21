# I used this to do some load testing
ESI::Config.define(listeners) do|config|

  # define the caching rules globally for all routes, defaults to ruby
  config.cache do|c|
    c.memcached do|mc|
      mc.servers = ['localhost:11211']
#      mc.debug = false
      mc.namespace = 'mesi'
#      mc.readonly = false
    end
    c.ttl = 600
  end

  # define rules for when to enable esi processing globally for all routes
  config.esi do|c|
    c.allowed_content_types = ['text/plain', 'text/html']
    #c.enable_for_surrogate_only = true # default is false
    c.chunk_size = 16384
    c.max_depth = 3
  end

  # define request path routing rules
  config.routes do|s|
    #s.match( /content/ ) do|r|
    #  r.servers = ['127.0.0.1:4000']
    #end
    s.default do|r|
      r.servers = ['10.0.6.130:80'] # apache server
    end
  end

end
