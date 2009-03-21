/* Copyright (c) 2008 Todd A. Fisher */
#include <stdio.h>
#include <stdlib.h>
#include <errno.h>
#include <assert.h>
#include <string.h>
#include <fcntl.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include "http_handler.h"
#include "router.h"

extern Siphon::Logger *glogger;

namespace Siphon {

HttpSock::HttpSock(struct ev_loop *loop, const HttpRouter &router)
  : Siphon::Sock(loop), m_handler(0), m_router(router), m_response(NULL)
{
  memset(&m_parser,0,sizeof(http_parser));
  http_parser_init(&m_parser);
  m_parser.data = this;
  m_parser.http_field     = (field_cb)http_field_cb;
  m_parser.request_method = (element_cb)request_method_cb;
  m_parser.request_uri    = (element_cb)request_uri_cb;
  m_parser.fragment       = (element_cb)fragment_cb;
  m_parser.request_path   = (element_cb)request_path_cb;
  m_parser.query_string   = (element_cb)query_string_cb;
  m_parser.http_version   = (element_cb)http_version_cb;
  m_parser.header_done    = (element_cb)header_done_cb;
}
HttpSock::~HttpSock()
{
  if( m_handler ) {
    delete m_handler;
  }
  if( m_response ) {
    delete m_response;
  }
}

int HttpSock::accept_cb(sp_io_t sock)
{
  struct sockaddr_in addr;
  socklen_t addr_len = sizeof(addr); 

  m_sock = accept(sock, (struct sockaddr*)&addr, &addr_len);
  if(m_sock < 0) {
    perror("accept()");
    return -1;
  }

  // set non blocking
  if( fcntl(m_sock, F_SETFL, fcntl(m_sock, F_GETFL,0) | O_NONBLOCK) == -1 ) {
    perror("fcntl()");
    return -1;
  }

  ev_io_set(&m_reader, m_sock, EV_READ);
  ev_io_set(&m_errors, m_sock, EV_ERROR);

  ev_timer_again(m_loop, &m_timeout);
  ev_io_start(m_loop, &m_reader);
  ev_io_start(m_loop, &m_errors);
  // start up writer watcher later

  return 0;
}
int HttpSock::input_cb(struct ev_io *watcher, int revents)
{
  ssize_t r = recv(m_sock, m_rbuffer, sizeof(m_rbuffer), 0 ); // nonblocking setup in accept_cb, instead of passing MSG_DONTWAIT
  if( r < 0 ) {
    if( r == EAGAIN || r == EWOULDBLOCK ) { return 0; }
    return -1;
  }
  if( r == 0 ) { return 0; }
//  printf( "reset timeout\n" );
  this->reset_timeout();
  if( !http_parser_is_finished( &m_parser ) ) {
    m_buffer.append( m_rbuffer, r );
//    printf( "recieved: %d, %s\n", (int)r, m_buffer.c_str() );
    http_parser_execute( &m_parser, m_buffer.c_str(), m_buffer.size(), (m_buffer.size()-r) );

    if( http_parser_has_error( &m_parser ) ) {
      printf("Error parsing connection!\n");
      this->schedule_close(); // on error schedule a close event
      return -1;
    }
  }

  return 0;
}

int HttpSock::error_cb(struct ev_io *watcher, int revents)
{
  printf( "got an error\n" );
  return 0;
}
int HttpSock::timeout_cb(ev_timer *watcher, int revents)
{
  // well, the connection was open longer then our timeout
  printf("connection timed out!\n");
  this->schedule_close();
  return 0;
}
int HttpSock::close_cb(ev_timer *watcher, int revents)
{
  if( m_response ) {
    this->m_response->close();
  }
  this->close();
  return 1; // socket is finished
}
void HttpSock::http_field_cb(HttpSock *sock, const char *field, long flen, const char *value, long vlen)
{
  const char *tail = NULL;
  String key;
  key.reserve(flen);

  tail = field + flen;

  while( field < tail ) {
    if(*field == '-') {
      key += '_';
    }else {
      key += toupper(*field);
    }
    ++field;
  }

  sock->m_params["HTTP_" + key] = String(value,vlen);
}
void HttpSock::request_method_cb(HttpSock *sock, const char *at, long length)
{
  sock->m_params["HTTP_REQUEST_METHOD"] = String(at,length);
}
void HttpSock::request_uri_cb(HttpSock *sock, const char *at, long length)
{
  sock->m_request_uri = sock->m_params["HTTP_REQUEST_URI"] = String(at,length);
}
void HttpSock::fragment_cb(HttpSock *sock, const char *at, long length)
{
  sock->m_params["HTTP_FRAGMENT"] = String(at,length);
}
void HttpSock::request_path_cb(HttpSock *sock, const char *at, long length)
{
  sock->m_request_path = sock->m_params["HTTP_REQUEST_PATH"] = String(at,length);
}
void HttpSock::query_string_cb(HttpSock *sock, const char *at, long length)
{
  sock->m_params["HTTP_QUERY_STRING"] = String(at,length);
}
void HttpSock::http_version_cb(HttpSock *sock, const char *at, long length)
{
  sock->m_params["HTTP_VERSION"] = String(at,length);
}
void HttpSock::header_done_cb(HttpSock *sock, const char *at, long length)
{
  if( sock->m_state ) { return; }
  sock->m_handler = sock->m_router.match(sock->m_request_path,sock);

  if( !sock->m_handler ) {
    glogger->error("No handler assigned to this route: %s\n", sock->m_request_path.c_str() );
    sock->schedule_close();
    return;
  }

  HttpRequest req(sock->request_buffer(), sock->m_params);
  sock->m_response = new HttpResponse(sock);

  sock->m_handler->process(req, *sock->m_response);

}

} // end namespace Siphon
