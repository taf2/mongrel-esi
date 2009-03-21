/* Copyright (c) 2008 Todd A. Fisher */
#include "config.h"
#include <stdio.h>
#include <string.h>
#include "mime_types.h"

extern Siphon::Logger *glogger;

namespace Siphon {

%%{
  machine mime_type_parser;

  action ext_start {
    //glogger->info("mime ext start: %c\n", *p);
    mark = p;
  }

  action ext_end {
    tmp = std::string(mark, p - mark);
    //glogger->info("mime ext stop: %c: %s\n", *p, tmp.c_str());
    exts.push_back( trim(tmp) );
  }

  action mime_start {
    //glogger->info("mime start: %c\n", *p);
    mark = p;
  }

  action mime_end {
    tmp = std::string(mark, p - mark);
    trim(tmp);
    //glogger->info("mime stop: %c: %s\n", *p, tmp.c_str());
    // add the extensions
    for( int i = 0, len = exts.size(); i < len; ++i ) {
      m_types[exts[i]] = tmp;
    }
    exts.clear();
  }

  ext = [a-z0-9] @ext_start [a-z0-9]* space %ext_end ;

  mime_type = [a-z\.\-0-9\+]+ '/' [a-z\.\-0-9\+]+ %mime_end space;

  main := ( ( (ext space* ext?)* '=' space* %mime_start mime_type  ) | space+ )+;
}%%

%%write data;

MimeTypeTable::MimeTypeTable()
  : m_default("application/octet-stream")
{
}
MimeTypeTable::~MimeTypeTable()
{
  m_types.clear();
}

bool MimeTypeTable::load(const char *mime_type_file)
{
  FILE *f = fopen(mime_type_file, "rb");
  if( !f ) {
    glogger->error("opening mime file: %s\n", mime_type_file );
    return true;
  }
  struct stat st;
  char *buffer = NULL;
  std::string tmp;
  std::vector<std::string> exts;
  char *mark = NULL;

  if( fstat( fileno(f), &st ) ) { glogger->error("reading mime file: %s\n", mime_type_file ); return true; }

  buffer = (char*)malloc(sizeof(char)*st.st_size);
  size_t r = fread( buffer, sizeof(char), st.st_size, f );
  if( r != (sizeof(char)*st.st_size) ) {
    glogger->info("reading mime file: %s\n", mime_type_file );
    goto error;
  }
  
  int cs;
  char *p, *pe, *eof;

  p = buffer;
  eof = pe = buffer + (sizeof(char)*st.st_size);

  %%write init;

  %%write exec;

  glogger->info("mime types loaded: %d\n", m_types.size() );
  for( TypeTable::iterator it = m_types.begin(); it != m_types.end(); ++it ) {
    glogger->info("type: %s => %s\n", it->first.c_str(), it->second.c_str() );
  }

  free(buffer);
  fclose(f);

  return false;

error:
  free(buffer);
  fclose(f);
  return true;
}

const String& MimeTypeTable::type(const String &request_path)const
{
  unsigned long len = request_path.length();
  const char *ptr = request_path.c_str();
  char *ext = strstr(ptr,".");
  if( !ext || (ext == (ptr+len-1)) ) { return m_default; }
  ++ext; // move past the .
  TypeTable::const_iterator it = m_types.find(ext);
  if( it != m_types.end() ) { return it->second; }
  return m_default;
}

}
