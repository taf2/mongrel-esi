/* Copyright (c) 2008 Todd A. Fisher */
#ifndef SIPHON_HTTP_RESPONSE_H
#define SIPHON_HTTP_RESPONSE_H

#include "config.h"
#include <string.h>
#include <stdlib.h>
#include <sys/types.h>
#include <sys/socket.h>
#include "sock.h"
#include <queue>

namespace Siphon {
  struct BufferNode {
    BufferNode( const char *buf, size_t len )
      : buffer( NULL ), 
        written(0),size(len) {
      buffer = (char*)calloc(size+1, sizeof(String::value_type) );
      memcpy(buffer, buf, size);
      buffer[size] = '\0';
    }

    BufferNode( const String &buf )
      : buffer( NULL ), 
        written(0),size(buf.length()) {
      buffer = (char*)calloc(size+1, sizeof(String::value_type) );
      memcpy(buffer, buf.c_str(), size);
      buffer[size] = '\0';
    }

    ~BufferNode(){ free(buffer); }

    inline const char *buffer_offset()const { return buffer + written; }
    inline unsigned long buffer_size()const { return size - written; }
    inline int send_buffer(int sock)const {
#ifdef HAVE_MSG_NOSIGNAL
      return send( sock, buffer_offset(), buffer_size(), MSG_NOSIGNAL );
#else
      return send( sock, buffer_offset(), buffer_size(), 0 );
#endif
    }

    char *buffer;
    unsigned long written; // how much of buffer has been sent
    unsigned long size;
  };
  typedef std::queue<BufferNode*> BufferChain;
  typedef void (*output_cb_t)(struct ev_loop *, struct ev_io *, int );
  typedef int (*finished_cb_t)(void* data);

  class HttpResponse {
  public:
    HttpResponse( Sock *sock );
    ~HttpResponse();
    short status;
    HttpParams header;

    int send_headers();

    int write( const String &buffer );
    int write( const char *data, size_t len );

    void finish();
    inline bool complete()const{ return m_complete; }

    void close();
 
    // stop the existing write watcher
    // start the watcher again with oc enabled
    void set_output_cb( output_cb_t oc, void *data );

    // called when all buffers have been written
    // if finished_cb returns 0, then the handler must call m_sock_handle->schedule_close when it's finished writing
    inline void set_finished_cb( finished_cb_t finished_cb, void *cbdata ){ m_finished_cb = finished_cb; m_finished_cbdata = cbdata; }

  protected:
    void output_cb(struct ev_loop *loop, struct ev_io *watcher, int revents);
    static void on_write_hook_cb(struct ev_loop *loop, struct ev_io *watcher, int revents);

  protected:
    bool m_finished, m_complete; // m_finished is lets input stream let write stream know it's finished, m_complete lets write stream know input stream is complete
    int m_sock;
    void *m_finished_cbdata;
    finished_cb_t m_finished_cb;
    struct ev_io m_writer;
    struct ev_loop *m_loop;
    BufferChain m_chain;
    Sock *m_sock_handle;
  };
}

#endif
