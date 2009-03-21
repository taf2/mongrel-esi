#ifndef SIPHON_PROXY_HANDLER_H
#define SIPHON_PROXY_HANDLER_H

#include "server.h"
#include "dir_handler.h"

namespace Siphon {

  class ProxyHandler : public Siphon::HttpHandler {
  public:
    ProxyHandler(const ConfParser &config, const ConfigMap &location_config, Siphon::HttpSock*sock);
    virtual ~ProxyHandler();
    virtual void process( Siphon::HttpRequest &request, Siphon::HttpResponse &response );
  protected:
    int connect(Siphon::HttpRequest &request);
    void stop_events();
    void watch();
    inline void schedule_close() { ev_timer_start(m_loop, &m_closer); }
    inline void reset_timeout() { ev_timer_again(m_loop, &m_timeout); }

    void upstream_failure();

    static void connect_cb(struct ev_loop *loop, struct ev_io *watcher, int revents);
    static void input_cb(struct ev_loop *loop, struct ev_io *watcher, int revents);
    static void write_cb(struct ev_loop *loop, struct ev_io *watcher, int revents);
    static void error_cb(struct ev_loop *loop, struct ev_io *watcher, int revents);
    static void timeout_cb(struct ev_loop *loop, ev_timer *watcher, int revents);
    static void close_cb(struct ev_loop *loop, ev_timer *watcher, int revents);
    static int finish_cb(void* data);
    static void signal_cb(struct ev_loop *loop, struct ev_signal *w, int signo);
  protected:
    int m_sock; // proxy client connection
    bool m_connected;
    struct ev_loop *m_loop;
    struct ev_io m_reader, m_errors, m_connector;
    struct ev_timer m_timeout, m_closer;
    struct ev_signal m_signals;
    char m_wbuffer[1024];
    char m_rbuffer[TCP_MAXWIN];
    HttpResponse *m_response;
    BufferNode *m_request_buffer;
    DirHandler *m_file_handler;
    //jmp_buf m_sigpipe_jumpbuffer;
  };

} // end namespace Siphon

#endif
