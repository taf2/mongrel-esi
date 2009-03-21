#include "mod_hello.h"

namespace Siphon {

void HelloWorld::process( Siphon::HttpRequest &request, Siphon::HttpResponse &response )
{
  Siphon::String buffer;

  buffer = "<html><head></head><body>";
  buffer += "Request: " + request.params["HTTP_REQUEST_PATH"];
  buffer += "\n</body></html>\n";

  response.status = 200;
  response.header["Server"] = "Siphon";
  response.header["Cache-Control"] = "no-cache";
  snprintf(m_wbuffer,1024,"%lu",buffer.length());
  response.header["Content-Length"] = m_wbuffer;
  response.send_headers();

  response.write(buffer);
  response.finish(); // mark it as finished
}

}
