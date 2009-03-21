#ifndef SIPHON_DIR_HANDLER_H
#define SIPHON_DIR_HANDLER_H

#include "server.h"

namespace Siphon {

  class DirHandler : public Siphon::HttpHandler {
  public:
    DirHandler(const ConfParser &config,
               const ConfigMap &location_config,
               Siphon::HttpSock*sock) : Siphon::HttpHandler(config, location_config, sock){}
    virtual ~DirHandler();

    virtual void process( Siphon::HttpRequest &request, Siphon::HttpResponse &response );

  protected:
    void send404( Siphon::HttpRequest &request, Siphon::HttpResponse &response );

    static int header_finished(void*data);
    void start_sendfile();

    static void on_write_hook_cb(struct ev_loop *loop, struct ev_io *watcher, int revents);
    static void on_read_hook_cb(struct ev_loop *loop, struct ev_io *watcher, int revents);

    void sendpart();

  protected:
    int m_fd;
#ifdef HAVE_TCP_CORK
    int m_corked;
#endif
#ifndef HAVE_SENDFILE
    struct ev_io m_reader, m_errors;
#endif
    off_t m_file_offset;
    size_t m_count;
    char m_wbuffer[1024];
    Siphon::HttpResponse *m_response;
  };
} // end namespace Siphon

#endif
