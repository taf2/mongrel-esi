#ifndef ESI_PARSER_H
#define ESI_PARSER_H

#include <cstring>
#include <string>

namespace ESI {
  // parse a fragment of ESI code from the start or pickup from a
  // previous state, buffer as little as possible
  class Parser {
  public:
    static const long buffer_size = 4096;
    enum Variable {
      HTTP_COOKIE = 0,
      QUERY_STRING = 1
    };

    Parser();
    ~Parser();

    // return's current data position
    char *execute(char *data, long len, bool eof = false);

    // tell the parser no more data will be sent to execute
    // you can call this after a <esi:try><esi:attempt>...</esi:try> block for example
    // the scanner will call this
    int finish();

    inline int state()const{ return cs; }
  private:

    inline void append_char(char p) { *(m_buffers[m_active_buffer]) += p; }
    inline std::string &active_buffer(){ return *(m_buffers[m_active_buffer]); }

    inline void prune_seq(const char*str) {
      std::string &buf = this->active_buffer();
      buf.erase(buf.end()-strlen(str), buf.end());
    }

  private:

    int cs, act;
    char *te, *ts;
    char *p, *pe, *eof;
    int m_stack_size;
    int m_stack_ptr, top;
    bool m_comment;
    int m_del_start;
    Variable m_variable;
    std::string m_value, m_buffer, m_attempt, m_except, m_choose;
    std::string* m_buffers[4];
    int m_active_buffer;
    int *stack;
  };
  
  // scan the document for a start sequence
  // then execute the parser
  class Scanner {
  public:

    Scanner();
    ~Scanner();

    // scan a chunk of data
    int scan( const char *data, long len );

    // let the scanner know everything is finished
    int finish();
  private:
    void buffer( char c );
    void clear_buffer();

    int m_state, m_buffer_index;
    const char *m_pos, *m_end;

    char m_buffer[12];
    char m_tag_buffer[12]; // include, inline, try, attempt, invalidate

    unsigned m_start_comment_matching:1;
    unsigned m_end_comment_matching:1;
    unsigned m_start_tag_matching:1;
    unsigned m_var_matching_type1:1;
    unsigned m_var_matching_type2:1;
  };

}

#endif
