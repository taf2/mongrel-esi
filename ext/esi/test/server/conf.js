
server.socket_backlog = 64; // e.g. see man listen
server.port = 4000;
server.connection_timeout  = 10;   // drop clients after 10 seconds of inactivity during request handling
server.connection_throttle = 0;    // no throttling
server.collect_interval    = 0;    // control the responsiveness of the server loop see ev.h for details
server.timeout_interval    = 0;    // similar to above

log.level  = "debug";
log.errors = "logs/error.log";
log.access = "logs/access.log";

server.default_type = "application/octet-stream";
server.keepalive_timeout = 65; 
server.gzip = true;

// setup the default root handler
location('/', function(s) {
  s.root = "/Users/taf2/work/";
  s.headers.expires(10).minutes_plus_access();

  if( s.request.exist() ) {
    s.headers.expires(1).day_plus_access();
    s.logging = false;
  }

  s.proxy_pass = [
    "127.0.0.1:8000",
    "127.0.0.1:8001",
    "127.0.0.1:8002"
  ];

  s.cache = "memcached";
  s.cache.servers = [
    "127.0.0.1:9000",
    "127.0.0.1:9000"
  ];

} );


// create a new handler
dir_handler         = new Siphon.DirHandler();
dir_handler.expires = 10;      // seconds
dir_handler.root    = "/Users/taf2/work/siphon";

// create a proxy handler
proxy_handler         = new Siphon.ProxyHandler();
proxy_handler.expires = 10;         // seconds sets Expires and Cache-Control: max-age=10

// define the servers to proxy requests to
proxy_handler.upstreams = [
  "127.0.0.1:8000",
  "127.0.0.1:8001",
  "127.0.0.1:8002"
];

// wait up to 10 seconds for a backend server to become available 
// before dropping the client request.
// will request based on server activity on the backend
// in otherwords, it won't proxy to app_host1 if it's
// currently servicing a request. Instead, it will proxy to 
// either app_host2 or app_host3. If neither of those hosts are 
// available it will wait upstream_max_wait time before rejecting the client request with 
// a 503 error
proxy_handler.upstream_max_wait = 10;

// enable edge side include processing
// tell the proxy to look for <esi:include tags
proxy_handler.esi = true;
// determine how many nested <esi:include tags the proxy should traverse before failing
proxy_handler.esi_nesting = 3;

var cache = new Siphon.MemCacheStore();
// setup the memcached server host locations
// cached pages will be evenly distributed to each server
cache.servers = [
  "127.0.0.1:9000",
  "127.0.0.1:9000"
];
cache.timeout = 0.5; // half a second, before giving up on cached record
cache.headers.cookies = true; // cached requests are request_path + cookies header value

// give the proxy handler the cache configuration
proxy_handler.cache_store = cache;

// config is the root object
config.debug = true; // enable noisy config, useful when debugging the configuration

// assign the handlers to specific routes
config.routes({
  "/app": proxy_handler,
  "/": dir_handler
});

config.worker_connections  = 1024; // how many incoming connections can we handle, e.g. see listen(2)
config.connection_timeout  = 10;   // drop clients after 10 seconds of inactivity during request handling
config.connection_throttle = 0;    // no throttling
config.collect_interval    = 0;    // control the responsiveness of the server loop see ev.h for details
config.timeout_interval    = 0;    // similar to above

// log paths can be relative to this file or absolute, when starting with /
config.add_log("logs/error.log", "error");
config.add_log("logs/access.log", "info");

config.mime_types["html htm shtml"] = "text/html";
config.mime_types["css"] = "text/css";
config.mime_types["xml rss"] = "text/xml";
config.mime_types["gif"] = "image/gif";
config.mime_types["jpeg jpg"] = "image/jpeg";
config.mime_types["js"] = "application/x-javascript";
config.mime_types["atom"] = "application/atom+xml";

config.mime_types["mml"] = "text/mathml";
config.mime_types["txt"] = "text/plain";
config.mime_types["jad"] = "text/vnd.sun.j2me.app-descriptor";
config.mime_types["wml"] = "text/vnd.wap.wml";
config.mime_types["htc"] = "text/x-component";

config.mime_types["png"] = "image/png";
config.mime_types["tif tiff"] = "image/tiff";
config.mime_types["wbmp"] = "image/vnd.wap.wbmp";
config.mime_types["ico"] = "image/x-icon";
config.mime_types["jng"] = "image/x-jng";
config.mime_types["bmp"] = "image/x-ms-bmp";
config.mime_types["svg"] = "image/svg+xml";

config.mime_types["jar war ear"] = "application/java-archive";
config.mime_types["hqx"] = "application/mac-binhex40";
config.mime_types["doc"] = "application/msword";
config.mime_types["pdf"] = "application/pdf";
config.mime_types["ps eps ai"] = "application/postscript";
config.mime_types["rtf"] = "application/rtf";
config.mime_types["xls"] = "application/vnd.ms-excel";
config.mime_types["ppt"] = "application/vnd.ms-powerpoint";
config.mime_types["wmlc"] = "application/vnd.wap.wmlc";
config.mime_types["xhtml"] = "application/vnd.wap.xhtml+xml";
config.mime_types["cco"] = "application/x-cocoa";
config.mime_types["jardiff"] = "application/x-java-archive-diff";
config.mime_types["jnlp"] = "application/x-java-jnlp-file";
config.mime_types["run"] = "application/x-makeself";
config.mime_types["pl pm"] = "application/x-perl";
config.mime_types["prc pdb"] = "application/x-pilot";
config.mime_types["rar"] = "application/x-rar-compressed";
config.mime_types["rpm"] = "application/x-redhat-package-manager";
config.mime_types["sea"] = "application/x-sea";
config.mime_types["swf"] = "application/x-shockwave-flash";
config.mime_types["sit"] = "application/x-stuffit";
config.mime_types["tcl tk"] = "application/x-tcl";
config.mime_types["der pem crt"] = "application/x-x509-ca-cert";
config.mime_types["xpi"] = "application/x-xpinstall";
config.mime_types["zip"] = "application/zip";

config.mime_types["bin exe dll"] = "application/octet-stream";
config.mime_types["deb"] = "application/octet-stream";
config.mime_types["dmg"] = "application/octet-stream";
config.mime_types["eot"] = "application/octet-stream";
config.mime_types["iso img"] = "application/octet-stream";
config.mime_types["msi msp msm"] = "application/octet-stream";

config.mime_types["mid midi kar"] = "audio/midi";
config.mime_types["mp3"] = "audio/mpeg";
config.mime_types["ra"] = "audio/x-realaudio";

config.mime_types["3gpp 3gp"] = "video/3gpp";
config.mime_types["mpeg mpg"] = "video/mpeg";
config.mime_types["mov"] = "video/quicktime";
config.mime_types["flv"] = "video/x-flv";
config.mime_types["mng"] = "video/x-mng";
config.mime_types["asx asf"] = "video/x-ms-asf";
config.mime_types["wmv"] = "video/x-ms-wmv";
config.mime_types["avi"] = "video/x-msvideo";
