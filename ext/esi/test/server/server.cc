/* Copyright (c) 2008 Todd A. Fisher */
#include <stdio.h>
#include <stdlib.h>
#include <errno.h>
#include <assert.h>
#include <string.h>
#include <fcntl.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include "server.h"

// server modules
#include "mod_hello.h"
#include "dir_handler.h"
#include "proxy_handler.h"

extern Siphon::Logger *glogger;

namespace Siphon {


int allocated_sockets = 0;


void HttpServer::on_connect(struct ev_loop *loop, struct ev_io *watcher, int revents)
{
  HttpServer *server = static_cast<HttpServer*>(watcher->data);
//  printf(" new connect\n" );

  if(EV_ERROR & revents) {
    glogger->error("on_connection() got error event, closing server. '%s'", strerror(errno));
    server->unlisten();
    return;
  }

//  printf( "new connect\n" );
  // create the new http socket
  ++allocated_sockets;
  HttpSock *sock = new HttpSock(loop, server->m_router);

  sock->accept_cb(server->m_sock);
}
void HttpServer::unlisten()
{
  ev_io_stop(m_loop, &m_conn_watcher);
  close(m_sock);
}


HttpServer::HttpServer( ConfParser &config )
  : m_router(config), m_config(config)
{
  // use the default loop, because we need to watch for signals
  m_loop = ev_default_loop(0); //ev_loop_new(0);
  ev_set_io_collect_interval(m_loop, m_config.get_core_int("ev_collect_interval", 0) );
  ev_set_timeout_collect_interval(m_loop, m_config.get_core_int("ev_timeout_interval", 0) );
  memset(&m_conn_watcher, 0, sizeof(struct ev_io) );
  m_conn_watcher.data = this;
  ev_init(&m_conn_watcher, on_connect);

  initialize_router();
}

static HandlerFactory *create_factory( const ConfParser &config, const ConfigMap &loc_config, const Siphon::String &name )
{
  if( name == "hello" ) {
    return new HttpHandlerFactory<HelloWorld>(config, loc_config);
  }
  else if( name == "file" ) { 
    return new HttpHandlerFactory<DirHandler>(config, loc_config);
  }
  else if( name == "proxy" ) {
    return new HttpHandlerFactory<ProxyHandler>(config, loc_config);
  }
  else {
    return NULL;
  }
}
Siphon::String &trim(Siphon::String &x)
{
  // trim leading whitespace
  while( isspace(x[0]) ){ x.erase(0, 1); }

  // trim trailing whitespace
  Siphon::String::iterator i = x.begin();
  while(i != x.end()) {
    if( isspace(*i) ) {i = x.erase(i); }
    else ++i;
  }
  return x;
}
    
void HttpServer::initialize_router()
{
  // loop over all location blocks in the config object
  for( ConfigSet::iterator it = m_config.location_config.begin(); it != m_config.location_config.end(); ++it ) {
    String name = trim(it->second["handler"]);
    String match = trim(it->first);

    if( name.empty() ) {
      glogger->error("config error: missing handler for location: '%s'\n", match.c_str() );
      exit(EXIT_FAILURE);
    }
    glogger->info("loading route: '%s' with handler: '%s'\n", match.c_str(), name.c_str() );
    HandlerFactory *factory = create_factory( m_config, it->second, name );
    if( !factory ) {
      glogger->error("config error: undefined handler '%s' for location: '%s'\n", name.c_str(), match.c_str() );
      exit(EXIT_FAILURE);
    }
    m_router.add_route( match.c_str(), factory );
  }
  if( m_config.location_config.empty() ) {
    glogger->error("Config error: there must be at least 1 location block assigned\n");
    exit(EXIT_FAILURE);
  }
}

HttpServer::~HttpServer()
{
  //ev_loop_destroy(m_loop);
}
int HttpServer::initialize_socket(const char *host, int port)
{
  struct linger ling = {0, 0};
  struct sockaddr_in addr;
  int flags = 1;

  m_sock = -1;

  if( (m_sock = socket(AF_INET, SOCK_STREAM, 0)) == -1) {
    glogger->error("socket(): %s", strerror(errno) );
    goto error;
  }
  
  setsockopt(m_sock, SOL_SOCKET, SO_REUSEADDR, (void *)&flags, sizeof(flags));
  setsockopt(m_sock, SOL_SOCKET, SO_KEEPALIVE, (void *)&flags, sizeof(flags));
  setsockopt(m_sock, SOL_SOCKET, SO_LINGER, (void *)&ling, sizeof(ling));

  memset(&addr, 0, sizeof(addr));
  addr.sin_family = AF_INET;
  addr.sin_port = htons(port);
  addr.sin_addr.s_addr = htonl(INADDR_ANY);

  if (bind(m_sock, (struct sockaddr *)&addr, sizeof(addr)) < 0) {
    glogger->error("bind: %s", strerror(errno) );
    goto error;
  }
  glogger->info("Binding to %d\n", port ); 
  return 0;
error:
  if(m_sock > 0) close(m_sock);
  return -1;
}
int HttpServer::setup_listener()
{
  int r;

  if( (r=listen(m_sock, m_config.get_core_int("backlog",CORE_BACKLOG))) < 0 ) {
    perror("listen");
    return r;
  }

  r = fcntl(m_sock, F_SETFL, fcntl(m_sock, F_GETFL, 0) | O_NONBLOCK);
  assert(0 <= r && "socket non-blocking failed!");

  r = 0;

  ev_io_set(&m_conn_watcher,m_sock, EV_READ | EV_ERROR);
  ev_io_start(m_loop, &m_conn_watcher);

  return r;
}
void HttpServer::enable()
{
  if( initialize_socket(m_config.get_core_str("bind",CORE_BIND).c_str(), m_config.get_core_int("port",CORE_PORT) ) ) {
    glogger->error("Error initializing socket\n" );
    return;
  }
  if( setup_listener() ) {
    glogger->error("Failed to initialize non blocking socket\n" );
    return;
  }
}

void HttpServer::run()
{
  glogger->info("Starting event loop\n");
  // TODO: this should really be moved out of the server and into something else so we can add multiple servers
  ev_loop(m_loop, 0);
}

void HttpServer::stop()
{
  close(m_sock);
  ev_unloop(m_loop, EVUNLOOP_ALL);
}

String HttpServer::assign_route( const char *uri, Siphon::HandlerFactory *factory)
{
  return m_router.add_route( uri, factory );
}

}// end namespace Siphon
