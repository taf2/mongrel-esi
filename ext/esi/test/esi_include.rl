/** 
 * Copyright (c) 2008 Todd A. Fisher
 * see LICENSE
 */
%%{
  machine esi_include;

	action esi_include_open {
		printf("open include\n");
	}

  action esi_include_max_age {
    printf("\tmax-age: %s\n", m_value.c_str() );
  }

  action esi_include_src_complete {
    printf("\turl: %s\n", m_value.c_str() );
  }
  action esi_include_alt_complete {
    printf("\talt: %s\n", m_value.c_str() );
  }

  action esi_include_onerror {
    printf("\tonerror: conntinue\n");
  }
  
  action esi_include_redirect {
    printf("\tredirect: %s\n", m_value.c_str());
  }

  action esi_include_timeout {
    printf("\ttimeout value: %s\n", m_value.c_str() );
  }
  
  action esi_include_error {
    fhold;
    printf( "ERROR parsing esi include at char: %c\n", *p );
    fret;
  }

  esi_include_attrs = (
    'src' space* '='  space* url_value @esi_include_src_complete |
    'alt' space* '='  space* url_value @esi_include_alt_complete |
    'onerror' space* '=' space* ( ('"continue"') | ("'continue'") ) @esi_include_onerror |
    'redirect' space* '=' space* yes_no_value @esi_include_redirect  |
    'method' space* '=' space* ( ('"' ('GET'|'POST') '"') | ("'" ('GET'|'POST') "'") ) |
    'max-age' space* '=' space* max_age_value @esi_include_max_age |
    'timeout' space* '=' space* timeout @esi_include_timeout
  ) @!esi_include_error;
  
  esi_include_machine := (
     space* @esi_include_open (esi_include_attrs space*)* space* '/>' @{ fret; }
  );

  action esi_include_begin {
    // purge <esi:include from buffer 
    this->prune_seq("<esi:include");
    fcall esi_include_machine;
  }


  # parse each attribute for the esi include tag
  esi_include = (
    '<esi:include' @esi_include_begin
  );
}%%
