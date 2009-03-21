/* Copyright (c) 2008 Todd A. Fisher */
#ifndef SIPHON_CONFIG_LOADER_H
#define SIPHON_CONFIG_LOADER_H

#include "config.h"
#include <v8.h>
#include "server.h"
#include "dir_handler.h"
#include "proxy_handler.h"

namespace Siphon {
  typedef std::map<std::string, std::string> StringMap;
  typedef std::map<std::string, std::string> Options;

  class Config {
  public:
    Config();
    ~Config();

    HttpServer *create(Siphon::Options &options);

    void destroy(HttpServer *server);

  private:
    // Convert a JavaScript string to a std::string.  To not bother too
    // much with string encodings we just use ascii.
    static inline std::string object2string(v8::Local<v8::Value> value) {
      v8::String::Utf8Value utf8_value(value);
      return std::string(*utf8_value,utf8_value.length());
    } 

    static v8::Handle<v8::ObjectTemplate> make_map_template();

    // Callbacks that access maps
    static v8::Handle<v8::Value> map_get(v8::Local<v8::String> name,
                                         const v8::AccessorInfo& info);
    static v8::Handle<v8::Value> map_set(v8::Local<v8::String> name,
                                         v8::Local<v8::Value> value,
                                         const v8::AccessorInfo& info);

    static v8::Handle<v8::Object> map2object(StringMap* obj);
    static StringMap* object2map(v8::Handle<v8::Object> obj);

  private:  
    static v8::Persistent<v8::ObjectTemplate> m_map_template;
  };
}

#endif
