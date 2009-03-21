/** 
 * Copyright (c) 2008 Todd A. Fisher
 * see LICENSE
 */
%%{
  machine esi_try;

  action esi_try_open {
    printf("open try: %c\n", *p);
    this->active_buffer().erase(this->active_buffer().end()-strlen("<esi:try>"), this->active_buffer().end());
    m_attempt.clear();
    m_except.clear();
    fcall esi_try_machine;
  }

  action esi_try_close {
    //m_buffer.erase(m_buffer.end()-strlen("</esi:try>"), m_buffer.end());
    printf("close try\n");
    printf("attempt: %s\n", m_attempt.c_str() );
    printf("except: %s\n", m_except.c_str() );
    fret;
  }

  action esi_attempt_open {
    printf("open attempt: %c\n", *p);
    m_active_buffer = 1;
    //m_attempt.erase(m_attempt.end()-strlen("<esi:attempt>"), m_attempt.end());
  }

  action esi_attempt_close {
    printf("close attempt\n");
    m_attempt.erase(m_attempt.end()-strlen("</esi:attempt>"), m_attempt.end());
    m_active_buffer = 0;
  }

  action esi_except_open {
    printf("open except\n");
    m_active_buffer = 2;
    //m_except.erase(m_except.end()-strlen("<esi:except>"), m_except.end());
  }

  action esi_except_close {
    printf("close except\n");
    m_except.erase(m_except.end()-strlen("</esi:except>"), m_except.end());
    m_active_buffer = 0;
  }

  action attempt_buffer {
    m_attempt += *p;
  }
  action except_buffer {
    m_except += *p;
  }

  action esi_try_error {
    fhold;
    printf( "ERROR parsing esi try at char: %c\n", *p );
    fret;
  }

  esi_try_machine := (
    space*
      '<esi:attempt>' @esi_attempt_open ( esi_basic_tags | any@attempt_buffer )* :>>'</esi:attempt>' @esi_attempt_close space*
      '<esi:except>' @esi_except_open ( esi_basic_tags | any@except_buffer )* :>>'</esi:except>' @esi_except_close space*
    '</esi:try>' @esi_try_close
  ) @!esi_try_error;

  esi_try = (
    '<esi:try>' %esi_try_open
  );
}%%
