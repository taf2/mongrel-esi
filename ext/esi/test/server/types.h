#ifndef SIPHON_TYPES_H
#define SIPHON_TYPES_H
#include "config.h"
#include "logger.h"
#include <string>
#include <vector>
#include <memory>
#include <map>
#include <ext/pool_allocator.h>
#include <regex.h>
#include <ev.h>

#define CORE_BACKLOG 1024
#define CORE_BIND "0.0.0.0"
#define CORE_PORT 8080
#define CORE_ERROR_LOG "log/error.log"
#define CORE_ACCESS_LOG "log/access.log"
#define CORE_ROOT "html"
#define CORE_COLLECT_INTERVAL 0
#define CORE_TIMEOUT_INTERVAL 0

namespace Siphon {
  typedef std::string String;
  typedef std::map<String,String> HttpParams; 

  Siphon::String &trim(Siphon::String &x);

  typedef int sp_io_t;

  enum HTTPMethod {
    GET = 1,
    POST = 2,
    DELETE = 3,
    PUT = 4
  };

  class Handler;
  class HandlerFactory;
  class HttpHandler;

  class HttpRouter;

  //typedef std::map<String,HandlerFactory*> HttpRouter; 

  static const char *HTTP_STATUS_100[] = {
    "100 Continue",
    "101 Switching Protocols"
  };
  
  static const char *HTTP_STATUS_200[] = {
    "200 OK", 
    "201 Created", 
    "202 Accepted", 
    "203 Non-Authoritative Information", 
    "204 No Content", 
    "205 Reset Content", 
    "206 Partial Content" 
  };
  
  static const char* HTTP_STATUS_300[] = {
    "300 Multiple Choices", 
    "301 Moved Permanently", 
    "302 Moved Temporarily", 
    "303 See Other", 
    "304 Not Modified", 
    "305 Use Proxy"
  };
  
  static const char* HTTP_STATUS_400[] = {
    "400 Bad Request", 
    "401 Unauthorized", 
    "402 Payment Required", 
    "403 Forbidden", 
    "404 Not Found", 
    "405 Method Not Allowed", 
    "406 Not Acceptable", 
    "407 Proxy Authentication Required", 
    "408 Request Time-out", 
    "409 Conflict", 
    "410 Gone", 
    "411 Length Required", 
    "412 Precondition Failed", 
    "413 Request Entity Too Large", 
    "414 Request-URI Too Large", 
    "415 Unsupported Media Type"
  };
  
  static const char* HTTP_STATUS_500[] = {
    "500 Internal Server Error", 
    "501 Not Implemented", 
    "502 Bad Gateway", 
    "503 Service Unavailable", 
    "504 Gateway Time-out", 
    "505 HTTP Version not supported"
  };

  inline const char *status_string(short code) {
    switch(code) {
    case 100:
    case 101:
      return HTTP_STATUS_100[code-100];
    case 200:
    case 201:
    case 202:
    case 203:
    case 204:
    case 205:
    case 206:
      return HTTP_STATUS_200[code-200];
    case 300:
    case 301:
    case 302:
    case 303:
    case 304:
    case 305:
      return HTTP_STATUS_300[code-300];
    case 400:
    case 401:
    case 402:
    case 403:
    case 404:
    case 405:
    case 406:
    case 407:
    case 408:
    case 409:
    case 410:
    case 411:
    case 412:
    case 413:
    case 414:
    case 415:
      return HTTP_STATUS_400[code-400];
    case 500:
    case 501:
    case 502:
    case 503:
    case 504:
    case 505:
      return HTTP_STATUS_500[code-500];
    default:
      return "500 Internal Server Error";
    }
  }

}
#endif
