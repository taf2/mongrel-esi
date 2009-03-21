/** 
 * Copyright (c) 2008 Todd A. Fisher
 * see LICENSE
 */
#include "ruby.h"
#include "parser.h"

#define DEBUG
#ifdef DEBUG
#define TRACE()  fprintf(stderr, "> %s:%d:%s\n", __FILE__, __LINE__, __FUNCTION__)
#else
#define TRACE() 
#endif

/* ruby 1.9 compat */
#ifndef RSTRING_PTR
#define RSTRING_PTR(str) RSTRING(str)->ptr
#endif

#ifndef RSTRING_LEN
#define RSTRING_LEN(str) RSTRING(str)->len
#endif

static VALUE rb_ESI;
static VALUE rb_ESIParser;

static 
VALUE ESIParser_set_output_cb( VALUE self )
{
  ESIParser *parser;

  if( !rb_block_given_p() ){
    rb_raise(rb_eArgError, "Block expected. Call this method with a closure. { ... }");
  }

  Data_Get_Struct( self, ESIParser, parser );

  rb_ivar_set( self, rb_intern("@output"), rb_block_proc() );

  return Qnil;
}

static
VALUE ESIParser_set_start_tag_cb( VALUE self )
{
  ESIParser *parser;

  if( !rb_block_given_p() ){
    rb_raise(rb_eArgError, "Block expected. Call this method with a closure. { ... }");
  }

  Data_Get_Struct( self, ESIParser, parser );

  rb_ivar_set( self, rb_intern("@start_tag_block"), rb_block_proc() );

  return Qnil;
}

static
VALUE ESIParser_set_end_tag_cb( VALUE self )
{
  ESIParser *parser;

  if( !rb_block_given_p() ){
    rb_raise(rb_eArgError, "Block expected. Call this method with a closure. { ... }");
  }

  Data_Get_Struct( self, ESIParser, parser );

  rb_ivar_set( self, rb_intern("@end_tag_block"), rb_block_proc() );

  return Qnil;
}

static 
void ESIParser_free( ESIParser *parser )
{
  esi_parser_free( parser );
}

/* default callbacks */
static void 
esi_parser_default_start_cb( const void *data,
                             const char *name_start,
                             size_t name_length,
                             ESIAttribute *attr,
                             void *user_data )
{
  VALUE start_tag_block = rb_ivar_get( (VALUE)user_data, rb_intern("@start_tag_block") );

  if( start_tag_block && !NIL_P(start_tag_block) && rb_respond_to( start_tag_block, rb_intern("call") ) ){
    VALUE attr_hash = rb_hash_new();
    VALUE tag_text = rb_str_new( name_start, name_length );
    while( attr ){
      VALUE name = rb_str_new( attr->name, attr->name_length );
      VALUE value = rb_str_new( attr->value, attr->value_length );
      rb_hash_aset( attr_hash, name, value );
      attr = attr->next;
    }
    rb_funcall( start_tag_block, rb_intern("call"), 2, tag_text, attr_hash );
  }
}

static void 
esi_parser_default_end_cb( const void *data,
                           const char *name_start,
                           size_t name_length,
                           void *user_data )
{
  VALUE end_tag_block = rb_ivar_get( (VALUE)user_data, rb_intern("@end_tag_block") );

  if( end_tag_block && !NIL_P(end_tag_block) && rb_respond_to( end_tag_block, rb_intern("call") ) ){
    VALUE tag_text = rb_str_new( name_start, name_length );
    rb_funcall( end_tag_block, rb_intern("call"), 1, tag_text );
  }
}

static void
send_output( VALUE output, VALUE esi_tag_context, VALUE rbstr )
{
  if( !NIL_P( esi_tag_context ) && rb_respond_to( esi_tag_context, rb_intern("buffer") ) ){
    /* a tag is currently open so send the output to it so that it can decide if the output is ready or not */
    rb_funcall( esi_tag_context, rb_intern("buffer"), 2, output, rbstr );
  }
  else{
    /* if no tag is in the current context send the output directly to the device */
    if( rb_respond_to( output, rb_intern("call") ) ){
      rb_funcall( output, rb_intern("call"), 1, rbstr );
    }
    else{
      rb_funcall( output, rb_intern("<<"), 1, rbstr );
    }
  }
}

static void 
esi_parser_default_output_cp( const void *data, size_t length, void *user_data )
{
  VALUE output = rb_ivar_get( (VALUE)user_data, rb_intern("@output") );
  VALUE esi_tag = rb_ivar_get( (VALUE)user_data, rb_intern("@esi_tag") );

  if( output && !NIL_P(output) ) {
    //if( length > 0 ) {
      VALUE rbstr = rb_str_new( data, length );
      //printf( "data length: %d\n", length );
      //rb_thread_schedule();
      send_output( output, esi_tag, rbstr );
    /*}else {
      printf( "rb_thread_schedule\n" );
      rb_thread_schedule();
    }*/
  }
}

static
VALUE ESIParser_process( VALUE self, VALUE data )
{
  ESIParser *parser;

  Data_Get_Struct( self, ESIParser, parser );

  return rb_int_new( esi_parser_execute( parser, RSTRING_PTR( data ), RSTRING_LEN( data ) ) );
}

static
VALUE ESIParser_flush( VALUE self )
{
  ESIParser *parser;

  Data_Get_Struct( self, ESIParser, parser );

  esi_parser_flush_output( parser );
  
  return Qnil;
}

static
VALUE ESIParser_finish( VALUE self )
{
  ESIParser *parser;

  Data_Get_Struct( self, ESIParser, parser );

  esi_parser_finish( parser );
  
  return Qnil;
}

static
VALUE ESIParser_alloc(VALUE klass)
{
  VALUE object;
  ESIParser *parser = esi_parser_new();

  esi_parser_init( parser );

  esi_parser_start_tag_handler( parser, esi_parser_default_start_cb );

  esi_parser_end_tag_handler( parser, esi_parser_default_end_cb );

  esi_parser_output_handler( parser, esi_parser_default_output_cp );

  object = Data_Wrap_Struct( klass, NULL, ESIParser_free, parser );

  parser->user_data = (void*)object;

  rb_ivar_set( object, rb_intern("@depth"), rb_int_new(0) );
  rb_ivar_set( object, rb_intern("@output"), Qnil );
  rb_ivar_set( object, rb_intern("@start_tag_block"), Qnil );
  rb_ivar_set( object, rb_intern("@end_tag_block"), Qnil );
  rb_ivar_set( object, rb_intern("@esi_tag"), Qnil );

  return object;
}

static
VALUE ESIParser_set_esi_tag( VALUE self, VALUE esi_tag )
{
  rb_ivar_set( self, rb_intern("@esi_tag"), esi_tag );
  return esi_tag;
}

static
VALUE ESIParser_get_esi_tag( VALUE self )
{
  return rb_ivar_get( self, rb_intern("@esi_tag") );
}

static
VALUE ESIParser_set_depth( VALUE self, VALUE depth )
{
  rb_ivar_set( self, rb_intern("@depth"), depth );
  return depth;
}

static
VALUE ESIParser_get_depth( VALUE self )
{
  return rb_ivar_get( self, rb_intern("@depth") );
}

static
VALUE ESIParser_set_output( VALUE self, VALUE output )
{
  rb_ivar_set( self, rb_intern("@output"), output );
  return output;
}

static
VALUE ESIParser_get_output( VALUE self )
{
  return rb_ivar_get( self, rb_intern("@output") );
}
static
VALUE ESIParser_send_output( VALUE self, VALUE output )
{
  ESIParser *parser;

  Data_Get_Struct( self, ESIParser, parser );

  esi_parser_default_output_cp( RSTRING_PTR(output), RSTRING_LEN(output), (void*)self );

  return Qnil;
}
void Init_esi()
{
  rb_ESI = rb_define_module( "ESI" );
  rb_ESIParser = rb_define_class_under( rb_ESI, "CParser", rb_cObject );

  rb_define_alloc_func( rb_ESIParser, ESIParser_alloc );

  rb_define_method( rb_ESIParser, "output_handler", ESIParser_set_output_cb, 0 );
  rb_define_method( rb_ESIParser, "start_tag_handler", ESIParser_set_start_tag_cb, 0 );
  rb_define_method( rb_ESIParser, "end_tag_handler", ESIParser_set_end_tag_cb, 0 );
  rb_define_method( rb_ESIParser, "process", ESIParser_process, 1 );
  rb_define_method( rb_ESIParser, "finish", ESIParser_finish, 0 );
  rb_define_method( rb_ESIParser, "flush", ESIParser_flush, 0 );
  rb_define_method( rb_ESIParser, "esi_tag=", ESIParser_set_esi_tag, 1 );
  rb_define_method( rb_ESIParser, "esi_tag", ESIParser_get_esi_tag, 0 );
  rb_define_method( rb_ESIParser, "depth=", ESIParser_set_depth, 1 );
  rb_define_method( rb_ESIParser, "depth", ESIParser_get_depth, 0 );
  rb_define_method( rb_ESIParser, "output", ESIParser_get_output, 0 );
  rb_define_method( rb_ESIParser, "output=", ESIParser_set_output, 1 );
  rb_define_method( rb_ESIParser, "output<<", ESIParser_send_output, 1 );

}
