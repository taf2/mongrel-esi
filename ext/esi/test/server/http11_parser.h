/**
 * Copyright (c) 2005 Zed A. Shaw
 * You can redistribute it and/or modify it under the same terms as Ruby.
 */

#ifndef http11_parser_h
#define http11_parser_h

#include <sys/types.h>

#if defined(_WIN32)
#include <stddef.h>
#endif

#ifdef __cplusplus
extern "C" {
#endif

typedef void (*element_cb)(void *data, const char *at, long length);
typedef void (*field_cb)(void *data, const char *field, long flen, const char *value, long vlen);

typedef struct http_parser { 
  int cs;
  long body_start;
  int content_len;
  long nread;
  long mark;
  long field_start;
  long field_len;
  long query_start;

  void *data;

  field_cb http_field;
  element_cb request_method;
  element_cb request_uri;
  element_cb fragment;
  element_cb request_path;
  element_cb query_string;
  element_cb http_version;
  element_cb header_done;
  
} http_parser;

int http_parser_init(http_parser *parser);
int http_parser_finish(http_parser *parser);
long http_parser_execute(http_parser *parser, const char *data, long len, long off);
int http_parser_has_error(http_parser *parser);
int http_parser_is_finished(http_parser *parser);

#define http_parser_nread(parser) (parser)->nread 
#ifdef __cplusplus
}// extern "C"
#endif

#endif

