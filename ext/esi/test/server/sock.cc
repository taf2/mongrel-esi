/* Copyright (c) 2008 Todd A. Fisher */

#include "sock.h"

namespace Siphon {

const float Sock::TIMEOUT;
extern int allocated_sockets;

Sock::Sock(struct ev_loop *loop) :  m_sock(-1), m_state(0), m_loop(loop)
{
  //printf("construct\n");
  ev_init(&m_reader, on_read_hook_cb);
	m_reader.data = this;
  ev_init(&m_errors, on_error_hook_cb);
	m_errors.data = this;
  ev_timer_init(&m_timeout, on_timeout_hook_cb, 0.0, TIMEOUT);
	m_timeout.data = this;
  ev_timer_init(&m_closer, on_close_hook_cb, 0.0, 0.0);
	m_closer.data = this;

  m_buffer.reserve(sizeof(m_rbuffer));
}
Sock::~Sock()
{
}

void Sock::close()
{
  //printf( "stopping event listeners\n" );
  ev_io_stop(m_loop,&m_reader);
  ev_io_stop(m_loop,&m_errors);
  ev_timer_stop(m_loop,&m_timeout);
  ev_timer_stop(m_loop,&m_closer);
  //printf( "shutdown socket\n" );
  //shutdown(m_sock,SHUT_RDWR);
  ::close(m_sock);
}

void Sock::on_read_hook_cb(struct ev_loop *loop,
                           struct ev_io *watcher,
                           int revents)
{
  static_cast<Sock*>(watcher->data)->input_cb(watcher,revents);
}
void Sock::on_error_hook_cb(struct ev_loop *loop,
                            struct ev_io *watcher,
                            int revents)
{
  static_cast<Sock*>(watcher->data)->error_cb(watcher,revents);
}
void Sock::on_timeout_hook_cb(struct ev_loop *loop,
                              struct ev_timer *timer,
                              int revents)
{
  static_cast<Sock*>(timer->data)->timeout_cb(timer,revents);
}
void Sock::on_close_hook_cb(struct ev_loop *loop,
                            struct ev_timer *timer,
                            int revents)
{
  Sock *sock = static_cast<Sock*>(timer->data);
  if( sock->close_cb(timer,revents) ) {
    delete sock; 
    --allocated_sockets;
  }
}

} // end namespace Siphon
