/** 
 * Copyright (c) 2008 Todd A. Fisher
 * see LICENSE
 */
%%{
  machine esi_common;

  prepush { 
    // stack growing code
    if( ++m_stack_ptr >= m_stack_size ) {
      // double it
      m_stack_size *= 2;
      this->stack = (int*)realloc(this->stack,sizeof(int)*m_stack_size);
    }
  }

  postpop {
    // stack shrinking code
    --m_stack_ptr;
    if( m_stack_ptr < 0 ) { m_stack_ptr = 0; } // something really wrong if this had to happen
  }
  
  action attr_value {
    m_value += *p;
  }

  action buffer_char {
    append_char(*p);
  }
 
  action esi_capture_value {
    m_value.clear();
  }

  attr_valueq1 = ('"' @esi_capture_value ("\\\""| [^"])* @attr_value :>> '"');
  attr_valueq2 = ("'" @esi_capture_value ("\\\'"| [^'])* @attr_value :>> "'");
  attr_value = (attr_valueq1 | attr_valueq2 );
  url_value = attr_value;
  
  max_age_value = ( ('"' @esi_capture_value ([0-9]@attr_value)+ ('+' @attr_value ([0-9]@attr_value)+)? '"') |
                    ("'" @esi_capture_value ([0-9]@attr_value)+ ('+' @attr_value ([0-9]@attr_value)+)? "'") );

  timeout = ( ('"' @esi_capture_value (([0-9]@attr_value)+)'"') |
              ("'" @esi_capture_value (([0-9]@attr_value)+)"'") );

  action value_is_yes {
    m_value = "yes";
  }
  action value_is_no {
    m_value = "no";
  }
  yes_no_value = ( ('"yes"' | "'yes'") @value_is_yes |
                   ('"no"' | "'no'") @value_is_no );

}%%
