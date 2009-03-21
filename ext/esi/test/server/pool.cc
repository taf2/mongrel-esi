#include "pool.h"

namespace Siphon {

Pool::Chunk::Chunk(Chunk *next, size_t size)
  : m_allocated(0), m_next(next)
{
  m_chunk_size = (size > DEFAULT_CHUNK_SIZE) ? size : DEFAULT_CHUNK_SIZE;
  m_memory = malloc(m_chunk_size);
}
Pool::Chunk::~Chunk()
{
  free(m_memory);
}
void *Pool::Chunk::alloc(size_t size)
{
  void *addr = (void*)((size_t)m_memory+m_allocated);
  m_allocated += size;
  return addr;
}

Pool::Pool( size_t default_size )
{
  this->expand(default_size);
}
Pool::~Pool()
{
  Chunk *chunk = m_list;
  while( chunk ) {
    m_list = chunk->next();
    delete chunk;
    chunk = m_list;
  }
}

void *Pool::alloc( size_t size )
{
  size_t space = m_list->allocated();
  if( space < size ) {
    expand(size);
  }
  return m_list->alloc(size);
}

void Pool::free( void *data )
{
  m_list->free(data);
}

void Pool::expand(size_t size)
{
  m_list = new Chunk(m_list, size);
}

} // end namespace Siphon
