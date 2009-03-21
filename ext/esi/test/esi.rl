/** 
 * Copyright (c) 2008 Todd A. Fisher
 * see LICENSE
 */
#include <stdio.h>
#include <stdlib.h>

#include "esi.h"

namespace ESI {

%%{
  machine esi_parser;

  include esi_common 'esi_common.rl';
  include esi_include 'esi_include.rl';
  include esi_inline 'esi_inline.rl';
  include esi_expr 'esi_expr.rl';
  include esi_vars 'esi_vars.rl';
  include esi_invalidate 'esi_invalidate.rl';
  include esi_comments 'esi_comments.rl';

  esi_basic_tags = (esi_include |
                    esi_inline |
                    esi_vars |
                    esi_invalidate |
                    esi_comment |
                    esi_html_comment
                    );

  include esi_choose 'esi_choose.rl';
  include esi_try 'esi_try.rl';

  # an esi start sequence was detected, parse out the interesting components of the ESI tag
  esi_tags = (
    esi_choose | 
    esi_try |
    esi_basic_tags 
  );
  
  # scan the input stream for an esi_tag start sequence
  main := ( ( any@buffer_char | esi_tags )* :>> '-->' @esi_check_comment )*;

}%%

%%write data;

Parser::Parser()
  :cs(0),act(),te(NULL),ts(NULL),
   p(NULL),pe(NULL),eof(NULL),
   m_stack_size(64),m_stack_ptr(0),top(0),
   m_comment(false)
{
	%% write init;
  m_value.reserve(buffer_size);
  m_buffer.reserve(buffer_size);
  m_attempt.reserve(buffer_size);
  m_except.reserve(buffer_size);
  m_choose.reserve(buffer_size);
  this->stack = (int*)malloc(sizeof(int)*m_stack_size);
  
  // setup the buffers array
  m_buffers[0] = &m_buffer;
  m_buffers[1] = &m_attempt;
  m_buffers[2] = &m_except;
  m_buffers[3] = &m_choose;

  m_active_buffer = 0;
}
Parser::~Parser()
{
  free( stack );
}

char *Parser::execute(char *data, long len, bool last_buf)
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

int Parser::finish()
{
  printf("buffer:\n%s, %d\n", m_buffer.c_str(), top );
  return 0;
}

}
