/** 
 * Copyright (c) 2008 Todd A. Fisher
 * see LICENSE
 */
%%{
  machine esi_vars;
  
  action esi_vars_begin {
    // purge <esi:vars from buffer 
    this->prune_seq("<esi:vars");
    fcall esi_vars_machine;
  }

  action esi_vars_finish {
    this->prune_seq("</esi:vars");
    fret;
  }

  action esi_vars_error {
    fhold;
    printf( "ERROR parsing esi vars at char: %c\n", *p );
    fret;
  }

  action esi_vars_variable {
    if( m_value.length() > 0 ) {
      this->active_buffer().erase(this->active_buffer().end()-(m_value.length()+4), this->active_buffer().end());
    }
    else {
      this->active_buffer().erase(this->active_buffer().end()-(m_value.length()+3), this->active_buffer().end());
    }
    printf("type: %d var key: '%s'\n", m_variable, m_value.c_str() );
  }

  esi_vars_machine := (
    space* '>' @esi_capture_value (any @buffer_char | esi_variable %esi_vars_variable )* :>> '</esi:vars>' @esi_vars_finish
  ) @!esi_vars_error;

  esi_vars = (
    '<esi:vars' @esi_vars_begin 
  );

}%%
