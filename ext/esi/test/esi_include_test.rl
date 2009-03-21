/** 
 * Copyright (c) 2008 Todd A. Fisher
 * see LICENSE
 *
 * Test only the <esi:include tag parsing.
 *
 * Specification:
 *
 * <esi:include src="URL_fragment" [alt="URL_fragment"]
 * [max-age="expiration_time [+removal_time]]" [method="GET|POST"] [onerror="continue"] [redirect=yes|no] [timeout="fetch_time"]/
 *
 * Note: 
 * Only the first inline element form is supported. e.g. <esi:request_header/<esi:request_body, etc... are not supported as inner tags.
 *
 * src: A URL that can be either cannonical http://domain.com/path/to/resource or absolute /path/to/resource/relative/to/requested/document
 * alt: A URL, similar to src, that will be used if src fails with a 40x or 50x response header.
 * max-age: gives the max time in seconds to cache the response body from src or alt. 
 *          If the second form is given e.g. 600+600 the second number after the + gives
 *          how long the cache server can keep the cached copy before purging it. 
 *          This is useful as it means the server does not have to refetch and block
 *          instead it can refetch and server the stale cached copy.
 * redirect: can be either yes or no and determines whether redirects should be followed. If no and an alt is given src will try the alt on a redirect.
 * method: The HTTP method to use for requesting the src or alt URL's.  Valid options are POST and GET other methods are unsupported.
 * onerror: Can be set to continue to ignore exceptions that might be raised from an error code 50x or missing resource code 40x from either src or alt.
 * timeout: How long to wait for src and alt to complete. It's important to note that the timeout includes both the time for src and alt. If src exceeds the timeout duration alt will not be attempted and instead an exception will be raised. 
 *          See esi:try for details about exception handling.
 *
 */
#include <stdio.h>
#include <stdlib.h>
#include "esi.h"
#include "esi_test_base.h"

%%{
  machine esi_include_test;
	include esi_common 'esi_common.rl';
	include esi_include 'esi_include.rl';
}%%


namespace ESI {

  %%write data;

  class ESIIncludeParserTest : public ESI::ESIParseTest {
  public:
    ESIIncludeParserTest() : ESIParseTest() {
      %% write init;
    }
    virtual ~ESIIncludeParserTest(){};
    // return's current data position
    virtual char *execute(char *data, long len, bool last_buf)
    {
      p = data;
      pe = data + len;
      if( last_buf ) {
        eof = pe;
      }
      else {
        eof = NULL;
      }

      %% write exec;
      //printf("cs: %d, %d, %ld\n", cs, pe - p, len );
      return this->p;
    }
  };
}

#define ESI_SAMPLE "sample2.html" 
#define BUFSIZE 1024

int main(int argc, char** argv)
{
  long len;
	char buf[BUFSIZE];
	FILE *input = fopen(ESI_SAMPLE,"rb");
  ESI::ESIIncludeParserTest parser;

	while ( input && !feof(input) && !ferror(input) ) {
		len = fread( buf, 1, BUFSIZE, input );
		if ( len == 0 )  break;
		parser.execute(buf,len, (len < BUFSIZE));
	} 

	fclose( input );

  return 0;

}
