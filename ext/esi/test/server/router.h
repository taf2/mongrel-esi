/* Copyright (c) 2008 Todd A. Fisher */
#ifndef SIPHON_HTTP_ROUTER_H
#define SIPHON_HTTP_ROUTER_H

#include "config.h"
#include "types.h"
#include "http_handler.h"
#include "conf_parser.h"

namespace Siphon {
  class HandlerFactory {
  public:
    HandlerFactory(const ConfParser &config, const ConfigMap &loc_config) : m_config(config), m_loc_config(loc_config) {}
    virtual ~HandlerFactory(){}
    virtual HttpHandler *create(Sock*sock)const = 0;
  protected:
    const ConfParser &m_config;
    const ConfigMap &m_loc_config;
  };

  template <typename T>
  class HttpHandlerFactory : public HandlerFactory  {
  public:
    HttpHandlerFactory(const ConfParser &config, const ConfigMap &loc_config) : HandlerFactory(config, loc_config){}
    virtual ~HttpHandlerFactory(){}
    virtual HttpHandler *create(Sock*sock)const {
      return new T(m_config, m_loc_config, static_cast<Siphon::HttpSock*>(sock));
    }
  };

  class HttpRouter {
  public:
    typedef std::pair<regex_t*,HandlerFactory*> Route;
    typedef std::vector<Route> Routes;
    HttpRouter(ConfParser &config);
    ~HttpRouter();

    String add_route( const char *match, HandlerFactory *factory);

    HttpHandler* match(const String &path, class HttpSock *sock)const;
  protected:
    Routes m_routes;
    ConfParser &m_config;
  };
}

#endif
