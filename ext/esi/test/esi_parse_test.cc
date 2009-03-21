#include <stdlib.h>
#include "esi_test_base.h"

namespace ESI {

ESIParseTest::ESIParseTest()
  :cs(0),act(),te(NULL),ts(NULL),p(NULL),pe(NULL),eof(NULL)
{
  this->eof = this->buffer + buffer_size;
  m_stack_size = 64; /* kinda big but... */
  top = m_stack_ptr = 0;
  this->stack = (int*)malloc(sizeof(int)*m_stack_size);
}
ESIParseTest::~ESIParseTest()
{
  free( stack );
}
// tell the parser no more data will be sent to execute
// you can call this after a <esi:try><esi:attempt>...</esi:try> block for example
// the scanner will call this
int ESIParseTest::finish()
{
  return 0;
}

}
