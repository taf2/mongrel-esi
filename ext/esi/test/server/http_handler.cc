/* Copyright (c) 2008 Todd A. Fisher */
#include <stdio.h>
#include <stdlib.h>
#include <assert.h>
#include <string.h>
#include <fcntl.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include "http_handler.h"

namespace Siphon {
HttpHandler::HttpHandler(const ConfParser &config,
                         const ConfigMap &location_config,
                         HttpSock *http_sock)
  : m_http_sock(http_sock), m_loc_config(location_config), m_config(config)
{
}

HttpHandler::~HttpHandler()
{
}

}
