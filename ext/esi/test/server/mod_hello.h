#ifndef SiphonHelloModule_H
#define SiphonHelloModule_H

#include "config.h"
#include <stdio.h>
#include <stdlib.h>
#include "server.h"

namespace Siphon {

  class HelloWorld : public Siphon::HttpHandler {
  public:
    HelloWorld(const Siphon::ConfParser &config,
               const Siphon::ConfigMap &location_config,
               Siphon::HttpSock *http_sock)
      : Siphon::HttpHandler(config, location_config, http_sock){}
    virtual ~HelloWorld(){}

    virtual void process( Siphon::HttpRequest &request, Siphon::HttpResponse &response );

  protected:
    char m_wbuffer[1024];
  };

}

#endif
