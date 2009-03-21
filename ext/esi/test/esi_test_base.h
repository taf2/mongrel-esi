#ifndef ESI_PARSER_TEST_H
#define ESI_PARSER_TEST_H
#include <string>
#include <vector>

namespace ESI {
  class TagInfo {
  public:
    TagInfo( const std::string &name ) : m_name(name){}

    void set_attr( const std::string &name, const std::string &value ) {
      m_attrs.push_back( std::pair<std::string,std::string>(name,value) );
    }

  private:
    std::string m_name;
    std::vector< std::pair<std::string,std::string> > m_attrs;
  };

  class ESIParseTest {
  public:
    static const long buffer_size = 4096;
    ESIParseTest();
    virtual ~ESIParseTest();
    // return's current data position
    virtual char *execute(char *data, long len, bool eof=false) = 0;

    // tell the parser no more data will be sent to execute
    // you can call this after a <esi:try><esi:attempt>...</esi:try> block for example
    // the scanner will call this
    int finish();

    inline int state()const{ return cs; }
  protected:
    int cs, act;
    char *te, *ts;
    char *p, *pe, *eof;
    char buffer[buffer_size];
    int *stack;
    int m_stack_size;
    int m_stack_ptr, top;

    std::string m_value;
    std::vector<TagInfo> m_tag_info;
  };
}

#endif
