/* Copyright (c) 2008 Todd A. Fisher */
#ifndef SIPHON_HTTP_SOCK_H
#define SIPHON_HTTP_SOCK_H
#include "config.h"
#include "types.h"
#include "sock.h"

namespace Siphon {
  class HttpSock : public Siphon::Sock {
  public:
    HttpSock(struct ev_loop *loop, const HttpRouter &router);
    virtual ~HttpSock(); 
    virtual int accept_cb(sp_io_t sock);
    virtual int input_cb(struct ev_io *watcher, int revents);
    virtual int error_cb(struct ev_io *watcher, int revents);
    virtual int timeout_cb(ev_timer *watcher, int revents);
    virtual int close_cb(ev_timer *watcher, int revents);

  protected:
    static void http_field_cb    (HttpSock *sock, const char *field, long flen, const char *value, long vlen);
    static void request_method_cb(HttpSock *sock, const char *at, long length);
    static void request_uri_cb   (HttpSock *sock, const char *at, long length);
    static void fragment_cb      (HttpSock *sock, const char *at, long length);
    static void request_path_cb  (HttpSock *sock, const char *at, long length);
    static void query_string_cb  (HttpSock *sock, const char *at, long length);
    static void http_version_cb  (HttpSock *sock, const char *at, long length);
    static void header_done_cb   (HttpSock *sock, const char *at, long length);
  protected:
    http_parser m_parser;
    HttpParams m_params;
    HTTPMethod m_method;
    HttpHandler *m_handler;
    String m_request_uri;
    String m_request_path;
    String m_request_body;
    const HttpRouter &m_router;

    HttpResponse *m_response;

  };
}
#endif
