/* Copyright (c) 2008 Todd A. Fisher */
#ifndef SIPHON_SOCK_H
#define SIPHON_SOCK_H
#include "config.h"
#include "types.h"
#include <netinet/tcp.h>

namespace Siphon {
  class Sock {
  public:
    static const float TIMEOUT = 10.0;

    Sock(struct ev_loop *loop);
    virtual ~Sock();

    virtual int accept_cb(sp_io_t sock) = 0;
    virtual int input_cb(struct ev_io *watcher, int revents) = 0;
    virtual int error_cb(struct ev_io *watcher, int revents) = 0;
    virtual int timeout_cb(ev_timer *watcher, int revents) = 0;
    virtual int close_cb(ev_timer *watcher, int revents) = 0;

    inline void reset_timeout() { ev_timer_again(m_loop, &m_timeout); }
    inline void schedule_close() { m_state = -1; ev_timer_start(m_loop, &m_closer); }
    inline struct ev_loop *get_loop(){ return m_loop; }
    inline const String &request_buffer()const{ return m_buffer; }

    sp_io_t m_sock;
  protected:
    void close();
    int m_state;
    struct ev_loop *m_loop;
    struct ev_io m_reader, m_errors;
    struct ev_timer m_timeout, m_closer;
    char m_rbuffer[TCP_MAXWIN];
    String m_buffer;
	private:
    static void on_read_hook_cb(struct ev_loop *loop, struct ev_io *watcher, int revents);
    static void on_error_hook_cb(struct ev_loop *loop, struct ev_io *watcher, int revents);
    static void on_timeout_hook_cb(struct ev_loop *loop, struct ev_timer *timer, int revents);
    static void on_close_hook_cb(struct ev_loop *loop, struct ev_timer *timer, int revents);
  };
}

#endif
