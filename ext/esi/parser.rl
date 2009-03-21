/** 
 * Copyright (c) 2008 Todd A. Fisher
 * see LICENSE
 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>
#include "parser.h"

#ifdef DEBUG
static void debug_string( const char *msg, const char *str, size_t len )
{
  char *pstr = esi_strndup( str, len );
  printf( "%s :'%s'\n", msg, pstr );
  free( pstr );
}
#else
#define debug_string(m,s,l)
#endif

/* define default callbacks */
static void 
esi_parser_default_start_cb( const void *data,
                             const char *name_start,
                             size_t name_length,
                             ESIAttribute *attributes,
                             void *user_data )
{
}
static void 
esi_parser_default_end_cb( const void *data,
                           const char *name_start,
                           size_t name_length,
                           void *user_data )
{
}
static void 
esi_parser_default_output_cp(const void *data,
                             size_t length,
                             void *user_data)
{
}

/* 
 * flush output buffer
 */
void esi_parser_flush_output( ESIParser *parser )
{
  if( parser->output_buffer_size > 0 ) {
    //debug_string( "esi_parser_flush_output:", parser->output_buffer, parser->output_buffer_size );
    parser->output_handler( (void*)parser->output_buffer, parser->output_buffer_size, parser->user_data );
    parser->output_buffer_size = 0;
  }
}
/* send the character to the output handler marking it 
 * as ready for consumption, e.g. not an esi tag
 */
static void esi_parser_echo_char( ESIParser *parser, char ch )
{
  parser->output_buffer[parser->output_buffer_size++] = ch;
  if( parser->output_buffer_size == ESI_OUTPUT_BUFFER_SIZE ) {
    // flush the buffer to the consumer
    esi_parser_flush_output( parser );
  }
}
static void esi_parser_send_buffer( ESIParser *parser, const char *seq, size_t len )
{
  const char *nseq = seq + len;
  size_t nlen = parser->output_buffer_size + len;

  if( nlen < ESI_OUTPUT_BUFFER_SIZE ) {
    memcpy( parser->output_buffer + parser->output_buffer_size, seq, len ); 
    parser->output_buffer_size += len;
  }
  else if( nlen > ESI_OUTPUT_BUFFER_SIZE ) {
    while( seq != nseq ) {
      esi_parser_echo_char( parser, *seq++ );
    }
  }
}
/* send any buffered characters to the output handler. 
 * This happens when we enter a case such as <em>  where the
 * first two characters < and e  match the <esi:  expression
 */
static void esi_parser_echo_buffer( ESIParser *parser )
{
  size_t i = 0, len = parser->echobuffer_index + 1;;
  //debug_string( "echobuffer", parser->echobuffer, parser->echobuffer_index+1 );
  //parser->output_handler( parser->echobuffer, parser->echobuffer_index+1, parser->user_data );
  for( ; i < len; ++i ) {
    esi_parser_echo_char( parser, parser->echobuffer[i] );
  }
}
/*
 * clear the buffer, no buffered characters should be emitted .
 * e.g. we matched an esi tag completely and all buffered characters can be tossed out
 */
static void esi_parser_echobuffer_clear( ESIParser *parser )
{
  parser->echobuffer_index = -1;
}

/*
 * add a character to the echobuffer. 
 * this happens when we can't determine if the character is allowed to be sent to the client device
 * e.g. matching <e  it's not yet determined if these characters are safe to send or not
 */
static void esi_parser_concat_to_echobuffer( ESIParser *parser, char ch )
{
  parser->echobuffer_index++;

  if( parser->echobuffer_allocated <= parser->echobuffer_index ) {
    /* double the echobuffer size 
     * we're getting some crazy input if this case ever happens
     */
    //printf( "increase echobuffer: %lu, %s\n", (long)parser->echobuffer_allocated, parser->echobuffer );
    parser->echobuffer_allocated *= 2;
    parser->echobuffer = (char*)realloc( parser->echobuffer, parser->echobuffer_allocated );
  }
  parser->echobuffer[parser->echobuffer_index] = ch;
//  debug_string( "echo buffer", parser->echobuffer, parser->echobuffer_index+1 );
}
/*
 * the mark boundary is not always going to be exactly on the attribute or tag name boundary
 * this trims characters from the left to right, advancing *ptr and reducing *len
 */
static void ltrim_pointer( const char **ptr, const char *bounds, size_t *len )
{
  // remove any spaces or = at the before the value
  while( (isspace( **ptr ) ||
         **ptr == '=' ||
         **ptr == '"' ||
         **ptr == '<' ||
         **ptr == '\'' ) && (*len > 0) && (*ptr != bounds) ) {
    (*ptr)++;
    (*len)--;
  }
}
/*
 * similar to ltrim_pointer, this walks from bounds to *ptr, reducing *len 
 */
static void rtrim_pointer( const char **ptr, const char *bounds, size_t *len )
{
  bounds = (*ptr+(*len-1));
  // remove any spaces or = at the before the value
  while( (isspace( *bounds ) ||
         *bounds == '=' ||
         *bounds == '"' ||
         *bounds == '>' ||
         *bounds == '\'') && (*len > 0) && (*ptr != bounds) ){
    bounds--;
    (*len)--;
  }
}

%%{
  machine esi;

  action begin {
    parser->mark = p;
    //debug_string( "begin", p, 1 );
  }
  action finish {
//    printf( "finish\n" );
  }

  # record the position of the start tag
  action see_start_tag {
    parser->tag_text = parser->mark+1;
    parser->tag_text_length = p - (parser->mark+1);
    parser->mark = p;
  }

  # detected an inline tag end, sends the start tag and end tag callback
  action see_end_tag {
    /* trim the tag text */
    ltrim_pointer( &(parser->tag_text), p, &(parser->tag_text_length) );
    rtrim_pointer( &(parser->tag_text), p, &(parser->tag_text_length) );

    /* send the start tag and end tag message */
    esi_parser_flush_output( parser );
    parser->start_tag_handler( data, parser->tag_text, parser->tag_text_length, parser->attributes, parser->user_data );
    parser->end_tag_handler( data, parser->tag_text, parser->tag_text_length, parser->user_data );
    //printf("\t[see inline tag]\n");

    if( parser->attributes ) {
      esi_attribute_free( parser->attributes );
      parser->attributes = NULL;
    }

    /* mark the position */
    parser->tag_text = NULL;
    parser->tag_text_length = 0;
    parser->mark = p;

    /* clear out the echo buffer */
    esi_parser_echobuffer_clear( parser );
  }

  # block tag start, with attributes
  action see_block_start_with_attributes {
    /* trim tag text */
    ltrim_pointer( &(parser->tag_text), p, &(parser->tag_text_length) );
    rtrim_pointer( &(parser->tag_text), p, &(parser->tag_text_length) );
    
    /* send the start and end tag message */
    esi_parser_flush_output( parser );
    parser->start_tag_handler( data, parser->tag_text, parser->tag_text_length, parser->attributes, parser->user_data );
    //printf("\t[see start tag with attributes]\n");
    
    if( parser->attributes ) {
      esi_attribute_free( parser->attributes );
      parser->attributes = NULL;
    }

    parser->tag_text = NULL;
    parser->tag_text_length = 0;
    parser->mark = p;
    
    /* clear out the echo buffer */
    esi_parser_echobuffer_clear( parser );
  }
  
  # see an attribute key, /foo\s*=/
  action see_attribute_key {
    /* save the attribute  key start */
    parser->attr_key = parser->mark;
    /* compute the length of the key */
    parser->attr_key_length = p - parser->mark;
    /* save the position following the key */
    parser->mark = p;

    /* trim the attribute key */
    ltrim_pointer( &(parser->attr_key), p, &(parser->attr_key_length) );
    rtrim_pointer( &(parser->attr_key), p, &(parser->attr_key_length) );
  }

  # see an attribute value, aprox ~= /['"].*['"]/
  action see_attribute_value {
    ESIAttribute *attr;

    /* save the attribute value start */
    parser->attr_value = parser->mark;
    /* compute the length of the value */
    parser->attr_value_length = p - parser->mark;
    /* svae the position following the value */
    parser->mark = p;
    
    /* trim the attribute value */
    ltrim_pointer( &(parser->attr_value), p, &(parser->attr_value_length) );
    rtrim_pointer( &(parser->attr_value), p, &(parser->attr_value_length) );

    /* using the attr_key and attr_value, allocate a new attribute object */
    attr = esi_attribute_new( parser->attr_key, parser->attr_key_length, 
                              parser->attr_value, parser->attr_value_length );

    /* add the new attribute to the list of attributes */
    if( parser->attributes ) {
      parser->last->next = attr;
      parser->last = attr;
    }
    else {
      parser->last = parser->attributes = attr;
    }
  }

  # simple block start tag detected, e.g. <esi:try> no attributes
  action block_start_tag {

    parser->tag_text = parser->mark;
    parser->tag_text_length = p - parser->mark;

    parser->mark = p;

    ltrim_pointer( &(parser->tag_text), p, &(parser->tag_text_length) );
    rtrim_pointer( &(parser->tag_text), p, &(parser->tag_text_length) );

    esi_parser_flush_output( parser );
    parser->start_tag_handler( data, parser->tag_text, parser->tag_text_length, NULL, parser->user_data );
    //printf("\t[see start tag]\n");
    
    if( parser->attributes ) {
      esi_attribute_free( parser->attributes );
      parser->attributes = NULL;
    }

    esi_parser_echobuffer_clear( parser );
  }

  # block end tag detected, e.g. </esi:try>
  action block_end_tag {
    /* offset by 2 to account for the </ characters */
    parser->tag_text = parser->mark+2;
    parser->tag_text_length = p - (parser->mark+2);

    parser->mark = p;
    
    ltrim_pointer( &(parser->tag_text), p, &(parser->tag_text_length) );
    rtrim_pointer( &(parser->tag_text), p, &(parser->tag_text_length) );
    
    esi_parser_flush_output( parser );
    parser->end_tag_handler( data, parser->tag_text, parser->tag_text_length, parser->user_data );
    //printf("\t[see end tag]\n");

    esi_parser_echobuffer_clear( parser );
  }

  # process each character in the input stream for output
  action echo {
    //printf( "[%c:%d],", *p, cs );
    switch( cs ) {
    case 0: /* non matching state */
      if( parser->prev_state != 12 && parser->prev_state != 7 ){ /* states following a possible end state for a tag */
        if( parser->echobuffer && parser->echobuffer_index != -1 ){
          /* send the echo buffer */
          esi_parser_echo_buffer( parser );
        }
        /* send the current character */
        esi_parser_echo_char( parser, *p );
      }
      /* clear the echo buffer */
      esi_parser_echobuffer_clear( parser );
      break;
    default:
      /* append to the echo buffer */
      esi_parser_concat_to_echobuffer( parser, *p );
    }
    /* save the previous state, necessary for end case detection such as />  and </esi:try>  the trailing > character
      is state 12 and 7
    */
    parser->prev_state = cs;
  }

  include esi_common_parser "common.rl";
}%%

%%write data;

/* dup the string up to len */
char *esi_strndup( const char *str, size_t len )
{
  char *s = (char*)malloc(sizeof(char)*(len+1));
  memcpy( s, str, len );
  s[len] = '\0';
  return s;
}

ESIAttribute *esi_attribute_new( const char *name, size_t name_length, const char *value, size_t value_length )
{
  ESIAttribute *attr = (ESIAttribute*)malloc(sizeof(ESIAttribute));
  attr->name = name;//esi_strndup(name, name_length);
  attr->value = value;//esi_strndup(value, value_length);
  attr->name_length = name_length;
  attr->value_length = value_length;
  attr->next = NULL;
  return attr;
}

ESIAttribute *esi_attribute_copy( ESIAttribute *attribute )
{
  ESIAttribute *head, *nattr;
  if( !attribute ){ return NULL; }

  // copy the first attribute
  nattr = esi_attribute_new( attribute->name, attribute->name_length,
                             attribute->value, attribute->value_length );
  // save a pointer for return
  head = nattr;
  // copy next attributes
  attribute = attribute->next;
  while( attribute ) {
    // set the next attribute
    nattr->next = esi_attribute_new( attribute->name, attribute->name_length,
                                     attribute->value, attribute->value_length );
    // next attribute
    nattr = nattr->next;
    attribute = attribute->next;
  }
  return head;
}

void esi_attribute_free( ESIAttribute *attribute )
{
  ESIAttribute *ptr;
  while( attribute ){
//    free( attribute->name );
//    free( attribute->value );
    ptr = attribute->next;
    free( attribute );
    attribute = ptr;
  }
}

ESIParser *esi_parser_new()
{
  ESIParser *parser = (ESIParser*)malloc(sizeof(ESIParser));
  parser->cs = esi_start;
  parser->mark = NULL;
  parser->tag_text = NULL;
  parser->attr_key = NULL;
  parser->attr_value = NULL;
  parser->overflow_data_size = 0;
  parser->overflow_data = NULL;
  parser->overflow_data_allocated = 0;
  parser->using_overflow = 0;

  /* allocate ESI_OUTPUT_BUFFER_SIZE bytes for the echobuffer */
  parser->echobuffer_allocated = ESI_ECHOBUFFER_SIZE;
  parser->echobuffer_index = -1;
  parser->echobuffer = (char*)malloc(sizeof(char)*parser->echobuffer_allocated);

  parser->attributes = NULL;
  parser->last = NULL;

  parser->start_tag_handler = esi_parser_default_start_cb;
  parser->end_tag_handler = esi_parser_default_end_cb;
  parser->output_handler = esi_parser_default_output_cp;

  parser->output_buffer_size = 0;
  memset( parser->output_buffer, 0, ESI_OUTPUT_BUFFER_SIZE );

  return parser;
}
void esi_parser_free( ESIParser *parser )
{
  if( parser->overflow_data ){ free( parser->overflow_data ); }

  free( parser->echobuffer );

  esi_attribute_free( parser->attributes );

  free( parser );
}

void esi_parser_output_handler( ESIParser *parser, output_cb output_handler )
{
  parser->output_handler = output_handler;
}

int esi_parser_init( ESIParser *parser )
{
  int cs;
  %% write init;
  parser->prev_state = parser->cs = cs;
  return 0;
}

static int compute_offset( const char *mark, const char *data, size_t length )
{
  if( mark && mark >= data && mark <= (data+length) ) {
    return mark - data;
  }
  return -1;
}

/*
 * scans the data buffer for a start sequence /<$/, /<e$/, /<es$/, /<esi$/, /<esi:$/
 * returns index of if start sequence found else returns -1
 */
static int
esi_parser_scan_for_start( ESIParser *parser, const char *data, size_t length )
{
  size_t i, f = -2, s = -2;
  char ch;

  for( i = 0; i < length; ++i ) {
    ch = data[i];
    switch( ch ) {
    case '<':
      f = s = i;
      break;
    case '/':
      if( s == (i-1) && f != -2 ) { s = i; }
      break;
    case 'e':
      if( s == (i-1) && f != -2 ) { s = i; }
      break;
    case 's':
      if( s == (i-1) && f != -2 ) { s = i; }
      break;
    case 'i':
      if( s == (i-1) && f != -2 ) { s = i; }
      break;
    case ':':
      if( s == (i-1) && f != -2 ) { s = i; return f; }
      break;
    default:
      f = s = -2;
      break;
    }
  }

  // if s and f are still valid at end of input return f
  if( f != -2 && s != -2 ) {
    return f;
  }
  else {
    return -1;
  }
}

#define imin(n1,n2) n1 < n2 ? n1 : n2

static void 
esi_parser_append_data_to_overflow_data( ESIParser *parser, const char *data, size_t length )
{
  int mark_offset       = 0;
  int tag_text_offset   = 0;
  int attr_key_offset   = 0;
  int attr_value_offset = 0;
  int start_offset      = 0; // we take the smallest of the
                             // above offsets to determine how
                             // much of data we really need

  if( parser->using_overflow ) {
    // recompute mark, tag_text, attr_key, and attr_value as they all exist within overflow_data
    mark_offset       = compute_offset( parser->mark,       parser->overflow_data, parser->overflow_data_size );
    tag_text_offset   = compute_offset( parser->tag_text,   parser->overflow_data, parser->overflow_data_size );
    attr_key_offset   = compute_offset( parser->attr_key,   parser->overflow_data, parser->overflow_data_size );
    attr_value_offset = compute_offset( parser->attr_value, parser->overflow_data, parser->overflow_data_size );
  }
  else {
    // recompute mark, tag_text, attr_key, and attr_value as they all exist within data
    mark_offset       = compute_offset( parser->mark,       data, length );
    tag_text_offset   = compute_offset( parser->tag_text,   data, length );
    attr_key_offset   = compute_offset( parser->attr_key,   data, length );
    attr_value_offset = compute_offset( parser->attr_value, data, length );
  }
 
  //printf( "mark_offset: %d, tag_text_offset: %d, attr_key_offset: %d, attr_value_offset: %d\n",
  //         mark_offset,     tag_text_offset,     attr_key_offset,     attr_value_offset );

  start_offset = 0; //imin( attr_value_offset, imin(attr_key_offset, imin(mark_offset,tag_text_offset) ) );
  if( mark_offset > 0 ) {
    start_offset = mark_offset;
    if( tag_text_offset > 0 ) {
      start_offset = imin(start_offset,tag_text_offset);
    }
    if( attr_key_offset > 0 ) {
      start_offset = imin(start_offset,attr_key_offset);
    }
    if( attr_value_offset > 0 ) {
      start_offset = imin(start_offset,attr_value_offset);
    }
  }

  if( parser->overflow_data ) {
    // TODO: shift the memory over by start_offset bytes before allocating more

    // check if we need to resize or grow the buffer
    if( (parser->overflow_data_size + length) > parser->overflow_data_allocated ) {
 
      parser->overflow_data_allocated += length;

      //printf( "realloc: %d bytes, using %d\n", (int)parser->overflow_data_allocated, (int)(parser->overflow_data_size+length) );
      parser->overflow_data = (char*)realloc( parser->overflow_data, sizeof(char)*(parser->overflow_data_allocated) );
    }

    //printf( "do the copy: %d, %d, %d\n", parser->overflow_data_size, length, parser->overflow_data_allocated );
    memcpy( parser->overflow_data+parser->overflow_data_size, data, length );
    parser->overflow_data_size += length;
  }
  else {
 
    //printf( "length: %d\n", length );

    /* recompute offsets and data start, based on the above offsets */
    if( attr_value_offset > 0 ) { attr_value_offset -= start_offset; }
    if( attr_key_offset > 0 )   { attr_key_offset   -= start_offset; }
    if( mark_offset > 0 )       { mark_offset       -= start_offset; }
    if( tag_text_offset > 0 )   { tag_text_offset   -= start_offset; }

    length -= start_offset;
    data   += start_offset;
    
    //printf( "start_offset: %d, mark_offset: %d, tag_text_offset: %d, attr_key_offset: %d, attr_value_offset: %d\n",
    //         start_offset,     mark_offset,     tag_text_offset,     attr_key_offset,     attr_value_offset );

    //printf( "recomputed length: %d\n", length );
    parser->overflow_data_allocated = ESI_OUTPUT_BUFFER_SIZE > length ? ESI_OUTPUT_BUFFER_SIZE : length;
    parser->overflow_data = (char*)malloc( sizeof( char ) * parser->overflow_data_allocated );
    memcpy( parser->overflow_data, data, length );
    parser->overflow_data_size = length;
    //printf( "malloc: %d for %d bytes\n", (int)parser->overflow_data_allocated, (int)length );
  }

  // in our new memory space mark will now be
  parser->mark = ( mark_offset >= 0 ) ? parser->overflow_data + mark_offset : NULL;
  parser->tag_text = ( tag_text_offset >= 0 ) ? parser->overflow_data + tag_text_offset : NULL;
  parser->attr_key = ( attr_key_offset >= 0 ) ? parser->overflow_data + attr_key_offset : NULL;
  parser->attr_value = ( attr_value_offset >= 0 ) ? parser->overflow_data + attr_value_offset : NULL;
}

/* accept an arbitrary length string buffer
 * when this methods exits it determines if an end state was reached
 * if no end state was reached it saves the full input into an internal buffer
 * when invoked next, it reuses that internable buffer copying all pointers into the 
 * newly allocated buffer. if it exits in a terminal state, e.g. 0 then it will dump these buffers
 */
int esi_parser_execute( ESIParser *parser, const char *data, size_t length )
{
  int cs = parser->cs;
  const char *p = data;
  const char *eof = NULL; // ragel 6.x compat
  const char *pe = data + length;
  int pindex;

  if( length == 0 ){ return cs; }

  /* scan data for any '<esi:' start sequences, /<$/, /<e$/, /<es$/, /<esi$/, /<esi:$/ */
  if( cs == esi_start || cs == 0 ) { 
    pindex = esi_parser_scan_for_start( parser, data, length );
    if( pindex == -1 ) { /* this means there are no start sequences in the buffer we recieved */
      esi_parser_send_buffer( parser, data, length );
      return cs; /* no esi start sequences send it all out and break out early */
    }
  }

  /* there's an existing overflow buffer and it's being used, append the new data */
  //if( parser->overflow_data && parser->overflow_data_size > 0 ) {
  if( parser->using_overflow ) {
    int prev_overflow_size = parser->overflow_data_size; // save the current overflow size
    //printf( "appending overflow: %d\n", prev_overflow_size );
    esi_parser_append_data_to_overflow_data( parser, data, length );

    /* set parser variables */
    p = parser->overflow_data + prev_overflow_size;
    data = parser->overflow_data;
    length = parser->overflow_data_size;
    pe = data + length;
  }

  if( !parser->mark ) {
    parser->mark = p;
  }

  %% write exec;

  parser->cs = cs;

  if( cs != esi_start && cs != 0 ) {

    /* reached the end and we're not at a termination point save the buffer as overflow */
    if( !parser->using_overflow ) { 
      esi_parser_append_data_to_overflow_data( parser, data, length );
      //printf( "reached overflow: %lu\n", parser->overflow_data_size );
      parser->using_overflow = 1;
    }

  } else if ( parser->using_overflow ) { 
    parser->using_overflow = 0;
    parser->overflow_data_size = 0;
  }

  return cs;
}
int esi_parser_finish( ESIParser *parser )
{
  esi_parser_flush_output( parser );
  return 0;
}

void esi_parser_start_tag_handler( ESIParser *parser, start_tag_cb callback )
{
  parser->start_tag_handler = callback;
}

void esi_parser_end_tag_handler( ESIParser *parser, end_tag_cb callback )
{
  parser->end_tag_handler = callback;
}
