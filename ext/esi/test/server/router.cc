/* Copyright (c) 2008 Todd A. Fisher */
#include <stdlib.h>
#include "router.h"

extern Siphon::Logger *glogger;

namespace Siphon {

HttpRouter::HttpRouter(ConfParser &config)
  : m_config(config)
{
}
HttpRouter::~HttpRouter()
{
	for( Routes::const_iterator it = m_routes.begin(); it != m_routes.end(); ++it ) {
		regfree( it->first );
    free( it->first );
		delete it->second;
	}
}

String HttpRouter::add_route( const char *match, HandlerFactory *factory)
{
	int r;
	regex_t *regex = (regex_t*)calloc(sizeof(regex_t),1);

	if( (r=regcomp(regex, match, REG_EXTENDED | REG_NOSUB) )) {
		char *erbuf = NULL;
		size_t size = regerror(r,regex,NULL,0);
		erbuf = (char*)malloc(sizeof(char)*(size+1));
		size = regerror(r,regex,erbuf,(size+1));
		String ret(erbuf,size);
		free(erbuf);
    glogger->error("Failed to create route for with: %s\n", ret.c_str() );
		return ret;
	}

	m_routes.push_back( Route(regex,factory) );

	return "";
}

HttpHandler* HttpRouter::match(const String &path, class HttpSock *sock)const
{
	// loop over all Route's and return the first HandlerFactory to match the path
	// or if no matches are found use the default Route
  const char *request_path = path.c_str();
	for( Routes::const_iterator it = m_routes.begin(); it != m_routes.end(); ++it ) {
		if( !regexec( it->first, request_path, 0, NULL, 0 ) ) {
      glogger->info("matched request: '%s'\n", request_path );
      return it->second->create(sock);
  	}
	}
  glogger->info("no match using last route for '%s'\n", request_path );
  // TODO: return default route
  return m_routes.back().second->create(sock);
}

}
