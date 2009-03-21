/* Copyright (c) 2008 Todd A. Fisher */
#include <stdlib.h>
#include <errno.h>
#include <sys/types.h>
#include <sys/socket.h>
#include "response.h"

namespace Siphon {

HttpResponse::HttpResponse( Sock *sock )
  : m_finished(false), m_complete(false), m_finished_cb(NULL), m_sock_handle(sock)
{
  m_sock = m_sock_handle->m_sock;
  ev_init(&m_writer, on_write_hook_cb);
  m_writer.data = this;
  ev_io_set(&m_writer, m_sock, EV_WRITE);
}

HttpResponse::~HttpResponse()
{
  if( !m_finished ) { finish(); }
  while( !m_chain.empty() ) {
    delete m_chain.front();
    m_chain.pop();
  }
}

void HttpResponse::set_output_cb( output_cb_t oc, void *data )
{
  ev_io_stop(m_sock_handle->get_loop(),&m_writer);
  ev_init(&m_writer, oc);
  m_writer.data = data;
  ev_io_start(m_sock_handle->get_loop(),&m_writer);
}

int HttpResponse::send_headers()
{
  String buffer;
  buffer.reserve(1024);
  buffer = "HTTP/1.1 ";
  buffer += status_string(status); 
  buffer += "\r\n";

  for( HttpParams::const_iterator it = header.begin(); it != header.end(); ++it ) {
    buffer += it->first;
    buffer += + ": ";
    buffer += it->second;
    buffer += "\r\n";
  }
  buffer += "\r\n";
  return this->write(buffer);
}

int HttpResponse::write( const char *data, size_t len )
{
  // create a new BufferNode
  BufferNode *node = new BufferNode( data, len );

  m_complete = false;

  if( m_chain.empty() ) {
    ev_io_start(m_sock_handle->get_loop(), &m_writer );
  }
  m_chain.push(node);
  return 0;
}
int HttpResponse::write( const String &buffer )
{
  // create a new BufferNode
  BufferNode *node = new BufferNode( buffer );

  m_complete = false;

  if( m_chain.empty() ) {
    ev_io_start(m_sock_handle->get_loop(), &m_writer );
  }
  m_chain.push(node);
  return 0;
}
void HttpResponse::close()
{
  ev_io_stop(m_sock_handle->get_loop(),&m_writer);
}

void HttpResponse::finish()
{
  m_finished = true;
}
 
void HttpResponse::output_cb(struct ev_loop *loop, struct ev_io *watcher, int revents)
{
  //printf( "write request\n" );
  BufferNode *node = m_chain.front();
  int sent = node->send_buffer(m_sock);
  if( sent < 0 ) {
    if( sent == EAGAIN || sent == EWOULDBLOCK ) {
      return;
    }
    //printf( "error scheduling close\n" );
    m_sock_handle->schedule_close();
    return;
  }
  //if( sent == 0 ) {
    //printf( "sent the whole buffer\n" );
  //}

  m_sock_handle->reset_timeout();

  node->written += sent;
  //printf( "sent: %lu of %lu\n", node->written, node->size );

  if( node->written == node->size ) {
    delete node;
    m_chain.pop();
    m_complete = false;
    if( m_chain.empty() ) {
      //printf("chain empty\n");
      m_complete = true;
      if( m_finished ) {
        if( !m_finished_cb || m_finished_cb(m_finished_cbdata) ) {
          //printf( "finished\n" );
          m_sock_handle->schedule_close();
        }
      }
      else {
        ev_io_stop(m_sock_handle->get_loop(), &m_writer);
      }
    }
  }
}

void HttpResponse::
on_write_hook_cb(struct ev_loop *loop,
                 struct ev_io *watcher,
                 int revents)
{
  //printf( "write request\n" );
  static_cast<HttpResponse*>(watcher->data)->output_cb(loop,watcher,revents);
}

}// end namespace Siphon
