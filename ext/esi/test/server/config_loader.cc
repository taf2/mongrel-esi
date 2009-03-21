#include "config_loader.h"

namespace Siphon {

void parse_options(int& argc, char**& argv, Siphon::Options& options)
{
  int ch;
  while ((ch = getopt(argc, argv, "hc:")) != -1) {
    switch(ch) {
    default:
    case 'h': // help requested
      fprintf(stderr,"usage: %s -c path_to_siphon_config\n", __FILE__);
      break;
    case 'c': // config path
      options["config"] = optarg;
      break;
    }
  }
  argc -= optind;
  argv += optind;
}

// Reads a file into a v8 string.
static v8::Handle<v8::String> read_javascript_file(const char* name)
{
  FILE* file = fopen(name, "rb");
  if (file == NULL) return v8::Handle<v8::String>();

  fseek(file, 0, SEEK_END);
  int size = ftell(file);
  rewind(file);

  char* chars = new char[size + 1];
  chars[size] = '\0';
  for (int i = 0; i < size;) {
    int read = fread(&chars[i], 1, size - i, file);
    i += read;
  }
  fclose(file);
  v8::Handle<v8::String> result = v8::String::New(chars, size);
  delete[] chars;
  return result;
}

static void report_javascript_exception(v8::TryCatch* try_catch)
{
  v8::HandleScope handle_scope;
  v8::String::Utf8Value exception(try_catch->Exception());
  v8::Handle<v8::Message> message = try_catch->Message();
  if (message.IsEmpty()) {
    // V8 didn't provide any extra information about this error; just
    // print the exception.
    printf("%s\n", *exception);
  } else {
    // Print (filename):(line number): (message).
    v8::String::Utf8Value filename(message->GetScriptResourceName());
    int linenum = message->GetLineNumber();
    printf("%s:%i: %s\n", *filename, linenum, *exception);
    // Print line of source code.
    v8::String::Utf8Value sourceline(message->GetSourceLine());
    printf("%s\n", *sourceline);
    // Print wavy underline (GetUnderline is deprecated).
    int start = message->GetStartColumn();
    for (int i = 0; i < start; i++) {
      printf(" ");
    }
    int end = message->GetEndColumn();
    for (int i = start; i < end; i++) {
      printf("^");
    }
    printf("\n");
  }
}

Config::Config()
{
}

Config::~Config()
{
}

HttpServer* Config::create(Siphon::Options &options)
{
  Siphon::String msg;

  v8::HandleScope handle_scope;

  // create the global config object
  v8::Handle<v8::ObjectTemplate> global          = v8::ObjectTemplate::New();
  v8::Handle<v8::ObjectTemplate> methods         = v8::ObjectTemplate::New();
  v8::Handle<v8::ObjectTemplate> siphon          = v8::ObjectTemplate::New();
  v8::Handle<v8::FunctionTemplate> dir_handler   = v8::FunctionTemplate::New();
  v8::Handle<v8::FunctionTemplate> proxy_handler = v8::FunctionTemplate::New();

  // setup headers hash for proxy_handler
  map2object

  // create the Siphon namespace object
  global->Set(v8::String::New("Siphon"), siphon);

  siphon->Set(v8::String::New("DirHandler"), dir_handler);
  siphon->Set(v8::String::New("ProxyHandler"), proxy_handler);

  // attach config methods

  // finally set the methods template as the object config
  global->Set(v8::String::New("config"), methods);

  // create the new context using config as the global object
  v8::Persistent<v8::Context> context = v8::Context::New(NULL,global);
  v8::Context::Scope context_scope(context);
  v8::Handle<v8::String> source = read_javascript_file(options["config"].c_str());

  printf( "loaded config source\n" );
  if( source.IsEmpty() ) {
    fprintf(stderr,"Failed to load configuration file: %s, please verify the file exists\n", options["config"].c_str() );
    return NULL;
  }

  // run the config script
  v8::TryCatch try_catch;
  v8::Handle<v8::Script> script = v8::Script::Compile(source, v8::String::New(options["config"].c_str() ));
  v8::Handle<v8::Value> result = script->Run();
  if( result.IsEmpty() ) {
    report_javascript_exception(&try_catch);
  }
  else {
    v8::String::Utf8Value str(result);
    printf("%s\n", *str);
  }

  context.Dispose();

  printf( "new server\n" );
  Siphon::HttpServer *server = new Siphon::HttpServer();
  
  msg = server->assign_route( "/", new Siphon::HttpHandlerFactory<Siphon::ProxyHandler>() );
	if( !msg.empty() ) { goto error; }

/*  msg = server->assign_route( "/hello", new Siphon::HttpHandlerFactory<HelloWorld>() );
	if( !msg.empty() ) { goto error; }

  msg = server->assign_route( "/.*", new Siphon::HttpHandlerFactory<Siphon::DirHandler>() );

	if( !msg.empty() ) { goto error; }
  */

  return server;
error:
  fprintf(stderr,"Route Error: %s\n", msg.c_str() );
  delete server;
  return NULL;
}

void Config::destroy(HttpServer *server)
{
}

// Callbacks that access maps
v8::Handle<v8::Value> Config::map_get(v8::Local<v8::String> name,
                                      const v8::AccessorInfo& info)
{
  StringMap *obj = object2map( info.Holder() );

  std::string key = object2string( name );

  StringMap::iterator iter = obj->find(key);

  // If the key is not present return an empty handle as signal
  if( iter == obj->end() ){ return v8::Handle<v8::Value>(); }

  // Otherwise fetch the value and wrap it in a JavaScript string
  const std::string& value = (*iter).second;
  return v8::String::New(value.c_str(), value.length());
}
v8::Handle<v8::Value> Config::map_set(v8::Local<v8::String> name,
                                      v8::Local<v8::Value> value_obj,
                                      const v8::AccessorInfo& info)
{
  StringMap *obj = object2map( info.Holder() );

  std::string key = object2string(name);
  std::string value = object2string(value_obj);

  (*obj)[key] = value;

  // Return the value; any non-empty handle will work.
  return value_obj;
}

v8::Handle<v8::Object> Config::map2object(StringMap* obj)
{
  v8::HandleScope handle_scope;
  if( m_map_template.IsEmpty() ) {
    v8::Handle<v8::ObjectTemplate> raw_template = make_map_template();
    m_map_template = v8::Persistent<v8::ObjectTemplate>::New(raw_template);
  }
  v8::Handle<v8::ObjectTemplate> templ = m_map_template;

  v8::Handle<v8::Object> result = templ->NewInstance();

  // Wrap the raw C++ pointer in an External so it can be referenced
  // from within JavaScript.
  v8::Handle<v8::External> map_ptr = v8::External::New(obj);

  // Store the map pointer in the JavaScript wrapper.
  result->SetInternalField(0, map_ptr);

  // Return the result through the current handle scope.  Since each
  // of these handles will go away when the handle scope is deleted
  // we need to call Close to let one, the result, escape into the
  // outer handle scope.
  return handle_scope.Close(result);
}
StringMap* Config::object2map(v8::Handle<v8::Object> obj)
{
  v8::Handle<v8::External> field = v8::Handle<v8::External>::Cast( obj->GetInternalField(0) );
  void *ptr = field->Value();
  return static_cast<StringMap*>(ptr);
}
v8::Handle<v8::ObjectTemplate> Config::make_map_template()
{
  v8::HandleScope handle_scope;
  v8::Handle<v8::ObjectTemplate> result = v8::ObjectTemplate::New();
  result->SetInternalFieldCount(1);
  result->SetNamedPropertyHandler(map_get, map_set);

  // Again, return the result through the current handle scope.
  return handle_scope.Close(result);
}

// define the static instance
v8::Persistent<v8::ObjectTemplate> Config::m_map_template;
}
