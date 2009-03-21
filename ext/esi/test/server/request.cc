/* Copyright (c) 2008 Todd A. Fisher */
#include "request.h"

namespace Siphon {
HttpRequest::HttpRequest(const String &rb, HttpParams &p)
  : params(p), request_buffer(rb)
{
}
HttpRequest::~HttpRequest()
{
}
}
