require 'uri'
require 'net/http'
require 'thread'
require 'webrick'
require 'timeout'
require 'yaml'

# keep webrick quiet
class ::WEBrick::HTTPServer
  def access_log(config, req, res)
    # nop
  end
end
class ::WEBrick::BasicLog
  def log(level, data)
    # nop
  end
end

#
# Simple test server
#
class TestServlet < WEBrick::HTTPServlet::AbstractServlet

  def self.port=(p)
    @port = p
  end

  def self.port
    (@port or 9129)
  end

  def self.path
    '/'
  end

  def self.url
    "http://127.0.0.1:#{port}#{path}"
  end

  def respond_with(method,req,res)
    res.body = method.to_s
    res['Content-Type'] = "text/plain"
  end

  def do_GET(req,res)
    if req.path == '/slow'
      res.body <<  "x"  * 10240
    elsif req.path == '/delay'
      res.body <<  "x"  * 10240
      sleep 0.01 # force a delay... annoying to keep large so bump up for special cases
      res.body <<  "x"  * 10240
    else
      respond_with(:GET,req,res)
    end
  end

  def do_POST(req,res)
    respond_with(:POST,req,res)
  end

  def do_PUT(req,res)
    respond_with(:PUT,req,res)
  end

  def do_DELETE(req,res)
    respond_with(:DELETE,req,res)
  end

end

module TestServerMethods
  def locked_file(port=9129)
    File.join(File.dirname(__FILE__),"server_lock-#{port}")
  end

  def server_setup(port=9129,servlet=TestServlet)
    port_var_name = "@__port#{port}"
    instance_variable_set(port_var_name,port)
    @__port = port
    if !defined?(@servers) or @servers.nil?
      @servers = []
      @threads = []
    end
    if !File.exist?(locked_file(instance_variable_get(port_var_name)))
      File.open(locked_file(instance_variable_get(port_var_name)),'w') {|f| f << 'locked' }

      # start up a webrick server for testing
      server = WEBrick::HTTPServer.new :Port => port, :DocumentRoot => File.expand_path(File.dirname(__FILE__))

      server.mount(servlet.path, servlet)

      test_thread = Thread.new { server.start }

      @servers << server
      @threads << test_thread

      exit_code = lambda do
        begin
          #puts "stopping: #{server}, #{instance_variable_get(port_var_name).inspect}"
          File.unlink locked_file(instance_variable_get(port_var_name)) if File.exist?(locked_file(instance_variable_get(port_var_name)))
          server.shutdown unless server.nil?
        rescue Object => e
          puts "Error #{__FILE__}:#{__LINE__}\n#{e.message}"
        end
      end

      return exit_code
    end
  end

  def siphon_setup
    pid_path = File.join(File.dirname(__FILE__),'..','build','default','log','siphon.pid')
    @siphon_conf ||= File.read(File.join(File.dirname(__FILE__),'siphon.conf'))
    @siphon_port ||= @siphon_conf.scan(/port: ([0-9]+)/).flatten.first.to_i

    if !File.exist?(pid_path)
      #puts "Starting Siphon"
      siphon_start = File.join(File.dirname(__FILE__),'..','build','default','siphon')
      siphon_start += " -d -c #{File.dirname(__FILE__)}/siphon.conf"
      system siphon_start 

      # don't wait too long
      Timeout::timeout(1) { sleep 0.01 until File.exist?(pid_path) }

      # pick up the pid file
      pidfile = File.read(pid_path).to_i

      #puts "Starting test servers"
      exit_code9998 = server_setup(9998)
      exit_code9999 = server_setup(9999)
      exit_code = lambda do
        exit_code9998.call
        exit_code9999.call
        Process.kill('TERM',pidfile)
      end
      trap('INT') { exit_code.call }
      at_exit { exit_code.call }
    end
  end
end

# Either takes a string to do a get request against, or a tuple of [URI, HTTP] where
# HTTP is some kind of Net::HTTP request object (POST, HEAD, etc.)
def hit(uris)
  results = []
  uris.each do |u|
    res = nil

    assert_nothing_raised do
      if u.kind_of? String
        res = Net::HTTP.get(URI.parse(u))
      else
        url = URI.parse(u[0])
        res = Net::HTTP.new(url.host, url.port).start {|h| h.request(u[1]) }
      end
    end

    assert_not_nil res, "Didn't get a response: #{u}"
    results << res
  end

  return results
end

def check_status(results, expecting)
  results.each do |res|
    assert(res.kind_of?(expecting), "Didn't get #{expecting}, got: #{res.class}")
  end
end
