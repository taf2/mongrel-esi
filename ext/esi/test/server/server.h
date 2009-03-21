/* Copyright (c) 2008 Todd A. Fisher */
#ifndef SIPHON_SERVER_H
#define SIPHON_SERVER_H

#include "config.h"
#include "router.h"
#include "http_handler.h"
#include "conf_parser.h"

/*
 * Siphon module containing all classes for handling HTTP Requests/Responses.
 */
namespace Siphon {

  /*
   * The center of the app, all requests are handled by this class
   *
   * Siphon::HttpServer *server = new Siphon::HttpServer("0.0.0.0",9000);
   *
   * server->assign_route("/path", new Siphon::HttpHandlerFactory<HelloWorld>());
   *
   * server->run();
   *
   * delete server;
   */
  class HttpServer {
  public:
    HttpServer( ConfParser &config );
    ~HttpServer();

    void enable();

    void run();
		String assign_route( const char *uri, Siphon::HandlerFactory *factory);
    void unassign_route( const char *uri );

    void stop();
  protected:
    // new connections
    static void on_connect(struct ev_loop *loop, struct ev_io *watcher, int revents);
    void unlisten();

    // server startup
    int initialize_socket(const char *host, int port);
    int setup_listener();
    void initialize_router();

    HttpRouter m_router;
    struct ev_loop *m_loop;
    struct ev_io m_conn_watcher;
    sp_io_t m_sock;
    ConfParser &m_config;
  };
}

#endif
