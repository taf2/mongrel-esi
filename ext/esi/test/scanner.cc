#include <stdio.h>
#include <stdlib.h>
#include "esi.h"

namespace ESI {

Scanner::Scanner()
  : m_state(0),m_buffer_index(0),
    m_pos(NULL),m_end(NULL)
{
  this->clear_buffer();
}
Scanner::~Scanner()
{
}

// scan a chunk of data
int Scanner::scan( const char *data, long len )
{
  // locate any ESI start sequences
  m_pos = data;
  m_end = data + len;

  while( m_pos != m_end ) {
    switch(*m_pos) {
    case '<':
      m_state = 1;
      buffer(*m_pos);
      break;
    case 'e':
      switch( m_state ) {
      case 1:
        buffer(*m_pos);
        m_start_tag_matching = 1;
        m_state = 2;
        break;
      case 20:
        buffer(*m_pos);
        m_start_comment_matching = 1;
        m_state = 2;
        break;
      }
      break;
    case 's':
      if( m_state == 2 ) { m_state = 3; buffer(*m_pos);}
      break;
    case 'i':
      if( m_state == 3 ) { 
        buffer(*m_pos);
        if( m_start_comment_matching ) {
          m_state = 0;
          m_end_comment_matching = 1;
          m_start_comment_matching = 0;
        }
        else {
          m_state = 4;
        }
      }
      break;
    case ':':
      if( m_state == 4 ) {
        buffer(*m_pos);
        m_state = 0;
        m_start_tag_matching = 0;
        m_buffer[m_buffer_index] = '\0';
        printf("start sequence:%s\n",m_buffer);
        m_buffer_index = 0;
      }
      break;
    case '!':
      if( m_state == 1 ) { m_state = 5; }
      break;
    case '-':
      switch( m_state ) {
      case 0: // prev: <
        m_state = 6;
        break;
      case 5: // prev: !
        m_state = 19;
        break;
      case 6: // prev: -
        m_state = 7;
        break;
      case 19: // prev: -
        m_state = 20;
        break;
      }
      break;
    case '>':
      if( m_state == 7 && m_end_comment_matching ) {
        m_end_comment_matching = 0;
        //printf( "end comment\n" );
        m_state = 0;
      }
      break;
    case '$':
      buffer(*m_pos);
      m_state = 8;
      break;
    case '(':
      if( m_state == 8 ) { m_state = 9; buffer(*m_pos);}
      break;
    case 'H':
      if( m_state == 9 ) { m_state = 10; buffer(*m_pos);}
      break;
    case 'T':
      if( m_state == 10 ) { m_state = 11; buffer(*m_pos);}
      else if( m_state == 11 ) { m_state = 12; buffer(*m_pos);}
      break;
    case 'P':
      if( m_state == 12 ) { m_state = 13; buffer(*m_pos);}
      break;
    case '_':
      if( m_state == 13 ) {
        buffer(*m_pos);
        m_state = 0;
        m_buffer[m_buffer_index] = '\0';
        printf("esi http var: %s\n", m_buffer);
        m_buffer_index = 0;
      }
      else if( m_state == 18 ) {
        buffer(*m_pos);
        m_state = 0;
        m_buffer[m_buffer_index] = '\0';
        printf("esi query string var: %s\n", m_buffer);
        m_buffer_index = 0;
      }
      break;
    case 'Q':
      if( m_state == 9 ) { m_state = 14; buffer(*m_pos);}
      break;
    case 'U':
      if( m_state == 14 ) { m_state = 15; buffer(*m_pos);}
      break;
    case 'E':
      if( m_state == 15 ) { m_state = 16; buffer(*m_pos);}
      break;
    case 'R':
      if( m_state == 16 ) { m_state = 17; buffer(*m_pos);}
      break;
    case 'Y':
      if( m_state == 17 ) { m_state = 18; buffer(*m_pos);}
      break;
    default:
      // advance to next char and reset state
      m_buffer_index = m_state = 0;
      m_buffer[m_buffer_index] = '\0';
      break;
    }
    //printf( "info:[%d,%c]\n", m_state, *m_pos );
    ++m_pos;
  }
  return m_state;
}

void Scanner::buffer( char c )
{
  m_buffer[m_buffer_index++] = c;
  // wrap
  if( (unsigned)m_buffer_index >= sizeof(m_buffer) ) {
    m_buffer_index = 0;
  }
}

void Scanner::clear_buffer()
{
  m_buffer_index = 0;
  memset(m_buffer,0,sizeof(m_buffer));
}

// let the scanner know everything is finished
int Scanner::finish()
{
  return m_state;
}

}
