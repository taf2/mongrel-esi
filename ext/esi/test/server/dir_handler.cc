#include "config.h"
#include <errno.h>
#include <dirent.h>
#include <netinet/in.h>
#include <sys/socket.h>
#include <sys/stat.h>
#include <fcntl.h>
#ifdef HAVE_SENDFILE_H
#include <sys/sendfile.h>
#endif
#include "dir_handler.h"

extern Siphon::Logger *glogger;

namespace Siphon {

DirHandler::~DirHandler()
{
}

void DirHandler::process( Siphon::HttpRequest &request, Siphon::HttpResponse &response )
{
  // get the core doc root
  String path = m_config.get_core_path("root", "/var/www/html/" );
  path += request.params["HTTP_REQUEST_PATH"];
  m_fd = open(path.c_str(), O_RDONLY);
  if( m_fd == -1 ) {
    send404(request,response);
    return;
  }
  struct stat buf;
  fstat(m_fd, &buf);

  if( S_ISDIR(buf.st_mode) ) {
    // provide a dir listing, this is a blocking operation :-(
#ifdef HAVE_FDOPENDIR
    DIR *dir = fdopendir(m_fd);
#else
    DIR *dir = opendir( path.c_str() );//__opendir2(path.c_str(), m_fd);
#endif
    String buffer;
    buffer.reserve(2096);
    buffer = "<html><head><title>" + path + "</title></head><body><ul>";
    if( dir ) {
      struct dirent *ep;
      std::string request_path;
      if( path.length() >= 2 && path[0] == '.' && path[1] == '/' ) {
        path.replace(0,1,"");
      }

      while( (ep = readdir(dir)) ) {
        if( ep->d_name[0] == '.' && ep->d_name[1] == '\0' ) { continue; }
        buffer += "<li>";
        buffer += "<a href=\"";
        request_path = path;
        if( path[path.length()-1] == '/' ) {
          request_path += ep->d_name;
        }
        else {
          request_path += "/";
          request_path += ep->d_name;
        }
        //printf("file: %s, rpath: %s\n", ep->d_name, request_path.c_str() );
        buffer += request_path;
        buffer += "\">";
        buffer += ep->d_name;
        buffer += "</a>";
        buffer += "</li>";
      }
      buffer += "</ul></body></html>";
      closedir(dir);
      response.status = 200;
      response.header["Server"] = "Siphon";
      //printf("buffer length: %s\n", buffer.c_str() );
      snprintf(m_wbuffer,1024,"%lu",buffer.length());
      response.header["Content-Length"] = m_wbuffer;
      //printf("buffer length: %s\n", m_wbuffer);
      response.send_headers();
      response.write(buffer);
      response.finish(); // mark it as finished
      close(m_fd);
    }
    else {
      send404(request,response);
    }
  }
  else if( S_ISREG(buf.st_mode) ) {
    m_count = buf.st_size;
    m_response = &response;
 
    // set non blocking
    if( fcntl(m_fd, F_SETFL, fcntl(m_fd, F_GETFL,0) | O_NONBLOCK) == -1 ) {
      perror("fcntl()");
      response.finish(); // mark it as finished
      return;
    }

    // send the HTTP Header
    response.status = 200;
    response.header["Server"] = "Siphon";
    response.header["Cache-Control"] = "no-cache";
    snprintf(m_wbuffer,sizeof(m_wbuffer),"%lu",m_count);
    response.header["Content-Length"] = m_wbuffer;
    // set contnet type
    response.header["Content-Type"] = m_config.mime_types.type(request.params["HTTP_REQUEST_PATH"]);

    response.send_headers();
#ifdef HAVE_SENDFILE_H
    response.set_finished_cb(header_finished, this);
    response.finish(); // mark it as finished
#else
    ev_init(&m_reader, on_read_hook_cb);
    m_reader.data = this;
    ev_io_set(&m_reader, m_fd, EV_READ);
    ev_io_start(m_http_sock->get_loop(), &m_reader);
#endif
  }
  else {
    send404(request,response);
  }
}

void DirHandler::send404( Siphon::HttpRequest &request, Siphon::HttpResponse &response )
{
  // return a 404 status
  String buffer;

  buffer = "<html><head></head><body>";
  buffer += "File not found: " + request.params["HTTP_REQUEST_PATH"];
  buffer += "\n</body></html>\n";

  response.status = 404;
  response.header["Server"] = "Siphon";
  response.header["Cache-Control"] = "no-cache";
  snprintf(m_wbuffer,1024,"%lu",buffer.length());
  response.header["Content-Length"] = m_wbuffer;
  response.send_headers();

  response.write(buffer);
  response.finish();
}

int DirHandler::header_finished(void*data)
{
  DirHandler *handler = static_cast<DirHandler*>(data);
  handler->start_sendfile();
  // if all is well return 0
  return 0;
}
void DirHandler::start_sendfile()
{
  //printf( "got the finish callback\n" );
  m_file_offset = 0;
  m_response->set_output_cb(on_write_hook_cb, this);

#ifndef HAVE_SENDFILE_H
#ifdef HAVE_TCP_CORK
  m_corked = 1;
  setsockopt(m_http_sock->m_sock, IPPROTO_TCP, TCP_CORK, &m_corked, sizeof(m_corked));
#endif
  this->sendpart();
#endif
}

void DirHandler::on_read_hook_cb(struct ev_loop *loop, struct ev_io *watcher, int revents)
{
  int ret;
  DirHandler *handler = static_cast<DirHandler*>(watcher->data);

  while( (ret=read(handler->m_fd, handler->m_wbuffer, sizeof(handler->m_wbuffer))) > 0 ) {
    handler->m_response->write(std::string(handler->m_wbuffer,ret));
  }

  if( ret == -1 && errno != EAGAIN ) {
    close(handler->m_fd);
    handler->m_response->finish();
    handler->m_http_sock->schedule_close();
    ev_io_stop(handler->m_http_sock->get_loop(),&handler->m_reader);
  }
  if( ret == 0 ) {
    close(handler->m_fd);
    handler->m_response->finish(); // mark it as finished
    ev_io_stop(handler->m_http_sock->get_loop(),&handler->m_reader);
  }
}

void DirHandler::on_write_hook_cb(struct ev_loop *loop, struct ev_io *watcher, int revents)
{
#ifdef HAVE_SENDFILE_H
  //printf( "send some data via sendfile\n" );
  DirHandler *handler = static_cast<DirHandler*>(watcher->data);
  handler->sendpart();
#endif
}

void DirHandler::sendpart()
{
#ifdef HAVE_SENDFILE_H
  ssize_t r;
  while( (r=::sendfile(m_http_sock->m_sock,m_fd,&m_file_offset, m_count)) == -1 ) {
    switch(errno) {
    case EINTR:
      printf("try again\n");
      break; /* try again */
    default:
      perror("sendfile()");
      close(m_fd);
      m_response->finish();
      m_http_sock->schedule_close();
      return;
    }
  }
  if( r == 0 ) {
    close(m_fd);
    m_response->finish();
    m_http_sock->schedule_close();
  }
  else {
    m_count -= m_file_offset;
  }
#endif
}
}
