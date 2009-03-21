#ifndef SIPHON_MIME_TYPES_H
#define SIPHON_MIME_TYPES_H

#include "config.h"
#include "types.h"

namespace Siphon {
  class MimeTypeTable {
  public:
    typedef std::map<std::string, std::string> TypeTable;
    MimeTypeTable();
    ~MimeTypeTable();

    bool load(const char *mime_type_file);

    void set_default(const String &type){ m_default = type; };

    const String &type(const String &request_path)const;
  private:
    TypeTable m_types;
    String m_default;
  };
}

#endif
