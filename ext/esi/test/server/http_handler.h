/* Copyright (c) 2008 Todd A. Fisher */
#ifndef SIPHON_HTTP_HANDLER_H
#define SIPHON_HTTP_HANDLER_H
#include "config.h"
#include "types.h"
#include "request.h"
#include "response.h"
#include "conf_parser.h"
#include "http11_parser.h"
#include "http_sock.h"

namespace Siphon {
  
  class HttpHandler {
  public:
    HttpHandler(const ConfParser &config, const ConfigMap &location_config, HttpSock *http_sock);
    virtual ~HttpHandler();

    virtual void process( Siphon::HttpRequest &reqeust, Siphon::HttpResponse &response ) = 0;
  protected:
    HttpSock *m_http_sock;
    const ConfigMap &m_loc_config;
    const ConfParser &m_config;
  };

}

#endif

