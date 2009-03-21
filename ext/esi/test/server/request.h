/* Copyright (c) 2008 Todd A. Fisher */
#ifndef SIPHON_HTTP_REQUEST_H
#define SIPHON_HTTP_REQUEST_H

#include "config.h"
#include "types.h"
#include "http11_parser.h"

namespace Siphon {
  class HttpRequest {
  public:
    HttpRequest(const String &rb, HttpParams &p);
    ~HttpRequest();
    HttpParams &params;
    const String &request_buffer;
  };
}

#endif
