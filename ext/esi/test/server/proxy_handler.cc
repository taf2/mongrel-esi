/* Copyright (c) 2008 Todd A. Fisher */
#include <stdio.h>
#include <stdlib.h>
#include <assert.h>
#include <string.h>
#include <errno.h>
#include <fcntl.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include "proxy_handler.h"
#include "hash_func.h"
#include "esi.h"

extern Siphon::Logger *glogger;

namespace Siphon {

ProxyHandler::ProxyHandler(const ConfParser &config, const ConfigMap &location_config, Siphon::HttpSock*sock)
  : Siphon::HttpHandler(config, location_config, sock), m_sock(-1), m_file_handler(NULL)
{
  m_loop = sock->get_loop();
  m_connected = false;
  // read from the proxy
  ev_init(&m_reader, input_cb);
	m_reader.data = this;

  // detect errors
  ev_init(&m_errors, error_cb);
	m_errors.data = this;

  // realize the client connection
  ev_init(&m_connector, connect_cb);
	m_connector.data = this;

  // timeout if the client takes too long
  ev_timer_init(&m_timeout, timeout_cb, 0.0, Siphon::Sock::TIMEOUT);
	m_timeout.data = this;
  
  // watch for some signals like sigpipe
  ev_signal_init(&m_signals, signal_cb, SIGPIPE);
  m_signals.data = this;

  // on errors of any kind initiate the close
  ev_timer_init(&m_closer, close_cb, 0.0, 0.0);
	m_closer.data = this;
}

ProxyHandler::~ProxyHandler()
{
  this->stop_events();
  if( m_file_handler ) {
    delete m_file_handler;
  }

  if( m_sock != -1 ) {
    ::close(m_sock);
  }

  if( m_request_buffer ) {
    delete m_request_buffer;
  }

}
void ProxyHandler::stop_events()
{
  //printf( "stopping event listeners\n" );
  ev_io_stop(m_loop,&m_reader);
  ev_io_stop(m_loop,&m_errors);
  ev_io_stop(m_loop,&m_connector);
  ev_timer_stop(m_loop,&m_timeout);
  ev_timer_stop(m_loop,&m_closer);
  ev_signal_stop(m_loop,&m_signals);
}

// connecting to a backend server upstream of this server, the proxy
int ProxyHandler::connect(Siphon::HttpRequest &request)
{
  struct linger ling = {0, 0};
  struct sockaddr_in addr;
  int flags = 1, r = 0;
  int port;
  String host;

  // locate the proxy configuration...
  // TODO: this can be done once, and maybe cached per connection?
  String proxy_name = m_config.get_location_str("proxy_config", m_loc_config);
  ConfigTree::const_iterator it = m_config.proxy_config.find(proxy_name);

  if( it != m_config.proxy_config.end() ) {
    const ConfigMap &proxy_config = it->second;
    /*int c = 0;
    int key = hash_key(request.params["HTTP_REQUEST_PATH"]);
    // select a host and port pair
    for( ConfigMap::const_iterator i = proxy_config.begin(); i != proxy_config.end(); ++i ) {
      host = i->second;
      ++c;
    }*/
    // TODO: figure out best way to rotate between upstream hosts
    host = proxy_config.begin()->second;
    String::size_type pos = host.find(":");
    if( pos == String::npos ) {
      port = 80;
    }
    else {
      port = atoi( host.substr(pos+1,host.size()).c_str() );
      host.erase(pos,host.size());
    }
  }
  else {
    glogger->error("Failed to find proxy config for '%s'\n", proxy_name.c_str() );
    goto error;
  }

  glogger->debug("conncting to socket\n");
  if( (m_sock = socket( AF_INET, SOCK_STREAM, 0 )) == -1) {
    glogger->error("socket(): '%s'\n", strerror(errno) );
    goto error;
  }

  setsockopt(m_sock, SOL_SOCKET, SO_REUSEADDR, (void *)&flags, sizeof(flags));
  setsockopt(m_sock, SOL_SOCKET, SO_KEEPALIVE, (void *)&flags, sizeof(flags));
  setsockopt(m_sock, SOL_SOCKET, SO_LINGER, (void *)&ling, sizeof(ling));

  memset(&addr, 0, sizeof(addr));
  addr.sin_family = AF_INET;
  addr.sin_port = htons(port);
  if( (r=inet_pton( AF_INET, host.c_str(), &addr.sin_addr )) == -1 || errno == EAFNOSUPPORT ) {
    glogger->error("inet_pton: %s\n", strerror(errno) );
    goto error;
  }

  // set to non blocking
  r = fcntl(m_sock, F_SETFL, fcntl(m_sock, F_GETFL, 0) | O_NONBLOCK);
  if( r == -1 ) {
    glogger->error("fcntl - Failed to set socket non-blocking, with: '%s'\n", strerror(errno) );
    goto error;
  }

  // socket on bsd can raise sig pipe if the backend is not present

  if( ::connect( m_sock, (const sockaddr*)&addr, sizeof(addr) ) != 0 ) {
    if( errno != EINPROGRESS ) {
      glogger->error("connect: %s\n", strerror(errno) );
      goto error;
    }
  }

  this->watch();

  return 0;

error:
  if(m_sock > 0) close(m_sock);
  return -1;
}

void ProxyHandler::watch()
{
  ev_io_set(&m_connector,m_sock, EV_WRITE);
  ev_io_set(&m_errors,m_sock, EV_ERROR);

  ev_io_start(m_loop, &m_connector);
  ev_io_start(m_loop, &m_errors);

  ev_timer_again(m_loop, &m_timeout);

  ev_signal_start(m_loop, &m_signals);

  // start read after we get a write
  glogger->debug("watching new socket\n");
}

void ProxyHandler::upstream_failure()
{
  String buffer;
  buffer.reserve(1024);
  buffer = "<html><head><title>Failed to connect to upstream server!</title></head><body>Proxy Error</body></html>";
  m_response->status = 500;
  m_response->header["Server"] = "Siphon";
  snprintf(m_wbuffer,1024,"%lu",buffer.length());
  m_response->header["Content-Length"] = m_wbuffer;
  m_response->header["Content-Type"] = "text/plain";
  m_response->send_headers();

  m_response->write(buffer);
  m_response->finish();
}

void ProxyHandler::process( Siphon::HttpRequest &request, Siphon::HttpResponse &response )
{
  // save the response
  m_response = &response;

  ConfigMap::const_iterator file_check = m_loc_config.find("check_file_first");
  if( file_check != m_loc_config.end() ) {
    String value = file_check->second;
    if( trim(value) == "true" ) {
      // check if the file exists?
      String path = m_config.get_core_path("root", "/var/www/html/" );
      path += request.params["HTTP_REQUEST_PATH"];
      int fd = open(path.c_str(), O_RDONLY);
      if( fd != -1 ) {
        struct stat buf;
        fstat(fd, &buf);
        if( !S_ISDIR(buf.st_mode) ) {
          close(fd); // ... little less efficient here...
          // if it's true we need to create a DirHandler and use that instead
          m_file_handler = new DirHandler( m_config, m_loc_config, m_http_sock );
          return m_file_handler->process( request, response );
        }
      }
      close(fd);
    }
  }

  // register call back to close down the client connection when the output is finished sending
  m_response->set_finished_cb(finish_cb,this);

  m_request_buffer = new Siphon::BufferNode( request.request_buffer );
  glogger->info( "request: %s\n", request.request_buffer.c_str() );

  if( this->connect(request) ) {
    this->upstream_failure();
  }
}

void ProxyHandler::connect_cb(struct ev_loop *loop, struct ev_io *watcher, int revents)
{
  ProxyHandler *ph = static_cast<ProxyHandler*>(watcher->data);

  // reset the timeout
  ph->reset_timeout();

  int sent = ph->m_request_buffer->send_buffer(ph->m_sock);
  if( sent < 0 ) {
    if( errno == EAGAIN || sent == EWOULDBLOCK ) {
      return;
    }
    ph->schedule_close();
    return;
  }
  ph->m_request_buffer->written += sent;
  if( sent == 0 || ph->m_request_buffer->written == ph->m_request_buffer->size  ) {
    // stop watching for write events on the client socket
    ev_io_stop(ph->m_loop,&ph->m_connector);
  }

  if( !ph->m_connected ) {
    // start watching for read events on the client socket
    ev_io_set(&ph->m_reader, ph->m_sock, EV_READ);
    ev_io_start(ph->m_loop, &ph->m_reader);
    ph->m_connected  = true;
  }
}

void ProxyHandler::signal_cb(struct ev_loop *loop, struct ev_signal *watcher, int signo)
{
  ProxyHandler *ph = static_cast<ProxyHandler*>(watcher->data);
  glogger->info("proxy recieved intterrupt signal: %d\n", signo);
  ph->upstream_failure();
}

void ProxyHandler::input_cb(struct ev_loop *loop, struct ev_io *watcher, int revents)
{
  int r;
  ProxyHandler *ph = static_cast<ProxyHandler*>(watcher->data);

  // reset the timeout
  ph->reset_timeout();

  do { // possible but unlikely we'll get an input callback and have more data to recv then sizeof(ph->m_rbuffer)
  glogger->debug("attempt to recv\n");

    r = recv(ph->m_sock, ph->m_rbuffer, sizeof(ph->m_rbuffer), 0);
    if( r == -1 ) {
      if( errno == EAGAIN ) { return; }
      // we got an error shutdown the connection
      ph->schedule_close();
      return;
    }
    glogger->debug( "input recieved %d bytes\n", r );

    if( r == 0 ) {
      ev_io_stop(ph->m_loop,&ph->m_reader);
      // done
      if( ph->m_response->complete() ) {
        //printf("input finished, write complete\n");
        ph->schedule_close(); // everything is done
      }
      else {
        //printf("input finished, pending write\n");
        ph->m_response->finish(); // input is finished, but we need to continue sending the response
      }
    }
    else {
      ph->m_response->write(ph->m_rbuffer, r);
    }

  } while( r > 0 );
}

void ProxyHandler::error_cb(struct ev_loop *loop, struct ev_io *watcher, int revents)
{
  glogger->error( "socket error\n" );
  ProxyHandler *ph = static_cast<ProxyHandler*>(watcher->data);
  ph->m_response->finish();
  ph->m_http_sock->schedule_close();
}

void ProxyHandler::timeout_cb(struct ev_loop *loop, ev_timer *watcher, int revents)
{
  // well, the connection was open longer then our timeout
  glogger->info("proxy connection timed out!\n");
  static_cast<ProxyHandler*>(watcher->data)->schedule_close();
}

void ProxyHandler::close_cb(struct ev_loop *loop, ev_timer *watcher, int revents)
{
  ProxyHandler *ph = static_cast<ProxyHandler*>(watcher->data);
  //printf("close_cb\n");
  ph->m_response->finish();
  ph->m_http_sock->schedule_close();
}
int ProxyHandler::finish_cb(void* data)
{
  //printf("finish_cb\n");
  ProxyHandler *ph = static_cast<ProxyHandler*>(data);
  ph->m_http_sock->schedule_close();
  ph->stop_events();
  return 1;
}

}// end namespace Siphon
