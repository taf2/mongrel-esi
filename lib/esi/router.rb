# Copyright (c) 2008 Todd A. Fisher
# see LICENSE

module ESI
 
  # ESI Server is a reverse proxy caching server.  It will forward all requests to app servers
  # by processing a config_file that specifies routes:
  #
  # content:
  #   host: 127.0.0.1
  #   port: 3000
  #   match_url: ^\/(content|samples|extra).*
  # default:
  #   host: 127.0.0.1
  #   port: 3001
  #
  # This sample configuration will route all urls starting with /content, /samples, or /extras
  # to the server running at 127.0.0.1 on port 3000
  # everything else that matches the .* will be routed to the server running on port 3001
  # optionally the caching duration can be specificied explicity for each host, this will be the default per host
  # if the esi:include tag does not specify otherwise
  #
  # default:
  #   host: 127.0.01
  #   port: 3001
  #
  # This example will cache all requests for 300 seconds, by default.
  #
  # To create a router load either from memory or file the above YAML
  #
  #   router = ESI::Router.new( YAML.load_file('config.yml') )
  #
  # or from memory
  #
  #   router = ESI::Router.new( YAML.load(config_str) )
  #
  class Router 

    # config is a routing table as defined above
    def initialize( routes )    
      @hosts = []
      @default = nil
 
      routes.each do|cfg|
        
        raise "Configuration error missing host for #{cfg.inspect}" if !cfg[:host]
        raise "Configuration error missing port for #{cfg.inspect}" if !cfg[:port]
        raise "Configuration error missing match_url for #{cfg.inspect}" if !cfg[:match_url]

        if cfg[:match_url] == 'default'
          @default = cfg
        else
          raise "Configuration error missing match_url for #{cfg.inspect}" if !cfg[:match_url]
          @hosts << cfg
        end

      end

      @default = {:host => '127.0.0.1', :port => '3000'} unless @default
    end

    # return a uri given a request_uri
    def url_for( request_uri )
      return request_uri if request_uri.match(/http:\/\//)
      # locate the first entry to match the given uri
      config = @hosts.find do |cfg|
        Regexp.new(cfg[:match_url]).match(request_uri)
      end
      config = @default unless config
      # build a url given a valid config or abort 404 not found
      "http://" + (config[:host] + ":" + (config[:port] || "").to_s + "/" + request_uri).squeeze("/")
    end

  end

end
