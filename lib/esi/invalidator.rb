# Copyright (c) 2008 Todd A. Fisher
# see LICENSE

# this is a separate thread that runs on port 4001
# when requests come to this they must authenticate
# and be of type POST
# the requests are processed as described by: http://www.w3.org/TR/esi-invp
require 'webrick'


module ESI
  module Invalidator

    def self.start( cache )
      Thread.new( cache ) do|cache|
        s = WEBrick::HTTPServer.new( :Port => 4001 )

        s.mount_proc("/invalidate"){|req, res|
          res.body = "<html>invalidate posted objects</html>"
          res['Content-Type'] = "text/html"
        }

        s.mount_proc("/status"){|req, res|
          res.body = "<html><body><h1>Cached objects</h1>"
          res.body << "<ul>"
          cache.keys do|key,data|
            res.body << "<li>#{key}</li>"
          end
          res.body << "</ul>"
          res.body << "</body>"
          res.body << "</html>"
          res['Content-Type'] = "text/html"
        }

        # XXX: this doesn't chain so ends up removing the mongrel trap locking the server up
        #trap("INT"){ s.shutdown }
        s.start
      end
    end

  end

end
