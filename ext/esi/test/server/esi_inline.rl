/** 
 * Copyright (c) 2008 Todd A. Fisher
 * see LICENSE
 */
%%{
  machine esi_inline;
	
  action esi_inline_open {
		printf("open inline\n");
	}

  action esi_inline_begin {
    // purge <esi:inline from buffer 
    this->prune_seq("<esi:inline");
    fcall esi_inline_machine; 
  }

  action esi_inline_finish {
    this->prune_seq("</esi:inline");
    printf( "esi_inline_finish\n" );
    fret;
  }

  action esi_inline_error {
    fhold;
    printf( "ERROR parsing esi inline at char: %c\n", *p );
    fret;
  }

  action esi_inline_name {
    printf("\tname: %s\n", m_value.c_str() );
  }
  
  action esi_inline_max_age {
    printf("\tmax-age: %s\n", m_value.c_str() );
  }

  action esi_inline_timeout {
    printf("\ttimeout: %s\n", m_value.c_str() );
  }

  action esi_inline_fetchable {
    printf("\tfetchable: %s\n", m_value.c_str() );
  }

  esi_inline = (
    '<esi:inline' @esi_inline_begin
  );

  esi_inline_fetchable = (
    ('"' 'yes' | 'no' '"') | ("'" 'yes' | 'no' "'")
  );

  esi_inline_attrs = (
    'name' space* '=' space* url_value @esi_inline_name |
    'fetchable' space* '=' space* yes_no_value @esi_inline_fetchable |
    'max-age' space* '=' space* max_age_value @esi_inline_max_age |
    'timeout' space* '=' space* timeout @esi_inline_timeout
  ) @!esi_inline_error;

  esi_inline_machine := (
    space* @esi_inline_open
    (esi_inline_attrs space*)* space* '>'
    any* @buffer_char:>> '</esi:inline>' @esi_inline_finish
  );

}%%
