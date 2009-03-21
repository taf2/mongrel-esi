/* Copyright (c) 2008 Todd A. Fisher */

#include "conf_parser.h"

namespace Siphon {

%%{
  machine conf_parser;

  action loc_match_start {
    this->mark = p;
  }
  
  action loc_match_compl {
    this->name = String(this->mark, p - this->mark);
    trim(this->name);
  }
  
  action loc_compl {
    location_config.push_back( std::pair<String,ConfigMap>( trim(this->name), ConfigMap(map_temp) ) );
    map_temp.clear();
  }

  action key_start {
    this->mark = p;
  }

  action key_compl {
    this->msg = String(this->mark, p - this->mark);
    trim( this->msg );
  }

  action val_start {
    this->mark = p;
  }
  
  action val_compl {
    String val = String(this->mark, p - this->mark);
    map_temp[this->msg] = trim(val);
  }

  action core_start {
    map_temp.clear();
  }
  action core_compl {
    core_config.swap( map_temp );
    map_temp.clear();
  }

  action proxy_match {
    this->mark = p;
  }
  action proxy_start {
    this->name = String(this->mark, p - this->mark);
    trim(this->name);
  }

  action proxy_compl {
    proxy_config[name] = ConfigMap( map_temp );
    map_temp.clear();
  }

  action comment_start {
    this->mark = p;
  }
  
  action comment_end {
    /*this->comment_count++;
    this->msg = String(this->mark, p - this->mark);
    trim(this->msg);*/
    //printf("comment %d: %s\n", this->comment_count, this->msg.c_str());
  }

  block_break = "\n" space*;
  comments = '#' @comment_start any* %comment_end :>> block_break;
  end_expr = space* (comments|"\n");
  key_pairs = '  ' [a-z] @key_start [a-z_A-Z0-9]* %key_compl :>> ':' space* %val_start any+ %val_compl :>> ';' end_expr;

  location = (
    start: (
      'location:' space* @loc_match_start any+  %loc_match_compl :>> end_expr -> keys
    ),
    keys: (
      key_pairs -> keys |
      block_break @loc_compl @/loc_compl -> final
    )
  );

  proxy = (
    start: (
      'proxy:' space* [a-zA-Z] @proxy_match [a-zA-Z_]* %proxy_start end_expr -> keys
    ),
    keys: (
      key_pairs -> keys |
      block_break @proxy_compl @/proxy_compl -> final
    )
  );

  core = (
    start: (
      'core:' %core_start space* end_expr -> keys
    ),
    keys: (
      key_pairs -> keys |
      block_break  @core_compl @/core_compl -> final
    )
  );

  main := ( comments | block_break | core | proxy | location )*;
}%%

%%write data;

ConfParser::ConfParser(const Siphon::String &bp)
  : base_path(bp)
{
  this->comment_count = 0;
}
ConfParser::~ConfParser()
{
}

void ConfParser::flush()
{
  core_config.clear();
  location_config.clear();
  proxy_config.clear();
  map_temp.clear();
}

int ConfParser::load( const char *file_path )
{
  FILE *input = NULL;
  struct stat st;
  char *buffer = NULL;

  input = fopen( file_path, "rb" );
  if( !input ) {
    return 1;
  }

  if( fstat( fileno(input), &st ) ) {
    return 1;
  }

  buffer = (char*)malloc(sizeof(char)*st.st_size);
  size_t r = fread( buffer, sizeof(char), st.st_size, input );
  if( r != (sizeof(char)*st.st_size) ) {
    fprintf(stderr, "Failed to read the contents of the config file: %s\n", file_path);
    goto error;
  }

  this->flush();
    
  int cs;
  char *p, *pe, *eof;

  p = buffer;
  eof = pe = buffer + (sizeof(char)*st.st_size);

  %%write init;

  %%write exec;
  
  free(buffer);
  fclose(input);

  return 0;

error:
  free(buffer);
  fclose(input);
  return 1;
}

void ConfParser::dump()const
{
  printf("core config:\n");
  for( ConfigMap::const_iterator it = core_config.begin(); it != core_config.end(); ++it ) {
    printf("  %s: %s;\n", it->first.c_str(), it->second.c_str() );
  }

  printf("#proxy configs\n");
  for( ConfigTree::const_iterator it = proxy_config.begin(); it != proxy_config.end(); ++it ) {
    printf( "proxy_config: %s\n", it->first.c_str() );
    for( ConfigMap::const_iterator jt = it->second.begin(); jt != it->second.end(); ++jt ) {
      printf("  %s: %s;\n", jt->first.c_str(), jt->second.c_str() );
    }
  }

  printf("#location configs\n");
  for( ConfigSet::const_iterator it = location_config.begin(); it != location_config.end(); ++it ) {
    printf( "location: %s\n", it->first.c_str() );
    for( ConfigMap::const_iterator jt = it->second.begin(); jt != it->second.end(); ++jt ) {
      printf("  %s: %s;\n", jt->first.c_str(), jt->second.c_str() );
    }
  }
}

}
