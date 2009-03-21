#ifndef SIPHON_CONF_PARSER_H
#define SIPHON_CONF_PARSER_H

#include "config.h"
#include "types.h"
#include "mime_types.h"

namespace Siphon {

  typedef std::map<String,String> ConfigMap;
  typedef std::vector<std::pair<String,ConfigMap> > ConfigSet;
  typedef std::map<String,ConfigMap> ConfigTree;

  class ConfParser {
  public:
    // base_path is used to make relative paths in the configuration file absolute
    ConfParser(const String &base_path);
    ~ConfParser();
 
    int load( const char *file_path );
    
    void dump()const;

    inline int get_core_int(const char *key)const {
      return get_core_int(key,0);
    }
    inline int get_core_int(const char *key, int default_value )const {
      ConfigMap::const_iterator loc = core_config.find(key);
      if( loc != core_config.end() ) {
        return atoi(loc->second.c_str());
      }
      else {
        return default_value;
      }
    }
    inline String get_core_str(const char *key)const {
      String empty;
      return get_core_str(key,empty);
    }
    inline String get_core_str(const char *key, const String &default_value)const {
      ConfigMap::const_iterator loc = core_config.find(key);
      if( loc != core_config.end() ) {
        return loc->second;
      }
      else {
        printf( "failed to find: '%s'\n", key );
        return default_value;
      }
    }

    inline String get_core_path(const char *key, const String &default_value)const {
      return this->abs_path(get_core_str(key,default_value));
    }

    inline String abs_path(const String &p)const {
      if( p[0] != '/' ) { return base_path + "/" + p; }else{ return p; }
    }

    inline String get_location_str(const char *key, const ConfigMap &cfg)const {
      ConfigMap::const_iterator it = cfg.find(key);
      if( it != cfg.end() ) { return it->second; }else { return ""; }
    }

    ConfigMap core_config;
    ConfigSet location_config;
    ConfigTree proxy_config;
    String base_path;
    MimeTypeTable mime_types;
  private:
    void flush();
    int comment_count;
    char *mark;
    String msg, name;
    ConfigMap map_temp;
  };

}

#endif
