require 'webrick'
class ::WEBrick::HTTPServer ; def access_log(config, req, res) ; end ; end
class ::WEBrick::BasicLog ; def log(level, data) ; end ; end

def start_net_server(port)
  server = WEBrick::HTTPServer.new( :Port => port )
  server.mount_proc("/") do|req,res|
    res.body = %Q(<html><body>Test Document</body></html>)
    sleep 0.001 # use a small delay to simulate network latency...
    res['Content-Type'] = "text/html"
  end
  @thread = Thread.new(server) do|s|
    s.start
  end
  server
end
