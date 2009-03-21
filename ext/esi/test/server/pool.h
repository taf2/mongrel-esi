#ifndef SIPHON_POOL_H
#define SIPHON_POOL_H

#include "config.h"
#include <stdlib.h>

namespace Siphon {
  class Pool {
    class Chunk {
    public:
      static const size_t DEFAULT_CHUNK_SIZE = 4096;
      Chunk(Chunk *next, size_t size);
      ~Chunk();

      void *alloc(size_t size);
      inline void free(void *ptr){}

      Chunk *next(){ return m_next; }

      size_t allocated()const{ return m_chunk_size - m_allocated; }

    private:
      size_t m_chunk_size;
      size_t m_allocated;
      Chunk *m_next;
      void  *m_memory;
    };

  public:

    Pool( size_t default_size = Chunk::DEFAULT_CHUNK_SIZE );
    ~Pool();

    void *alloc( size_t size );

    void free( void *data );
  private:
    Chunk *m_list;

    void expand(size_t size);
  };

  template<typename T>
  class PoolAllocator {
    typedef size_t		size_type;			  // A type that can represent the size of the largest object in the allocation model.
    typedef ptrdiff_t	difference_type;	// A type that can represent the difference between any two pointers in the allocation model.
    typedef T			    value_type;			  // Identical to T.
    typedef T*			  pointer;			    // Pointer to T;
    typedef T const*	const_pointer;		// Pointer to const T.
    typedef T&			  reference;			  // Reference to T.
    typedef T const&	const_reference;	// Reference to const T.
    
    // A struct to construct an allocator for a different type.
    template<typename U> 
    struct rebind { typedef PooledAllocator<U> other; };
    
    // Creates a pooled allocator to the given pool.
    // This is non-explicit for ease of use.
    PooledAllocator( Pool* pool = 0 ) : m_pool( pool ) 
    {
    }

    // Creates a pooled allocator to the argument's pool.
    // If the argument has no pool, then this allocator will allocate off the heap.
    template<typename U>
    PooledAllocator( PooledAllocator<U> const& arg ) : m_pool( arg.m_pool )
    {
    }
  };
};

#endif
