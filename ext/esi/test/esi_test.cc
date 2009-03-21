#include <stdio.h>
#include <stdlib.h>

#include "esi.h"


#define ESI_SAMPLE "sample.html" 
#define BUFSIZE 1024

int main( int argc, char **argv )
{
  int len;
	char buf[BUFSIZE];
	FILE *input = fopen(ESI_SAMPLE,"rb");

  ESI::Parser parser;

	while ( input &&
          !feof(input) &&
          !ferror(input) &&
          (len = fread( buf, 1, BUFSIZE, input )) ) {
		parser.execute(buf,len, (len < BUFSIZE));
	} 

  parser.finish();

	fclose( input );

	return 0;
}
