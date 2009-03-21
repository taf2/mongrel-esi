/** 
 * Copyright (c) 2008 Todd A. Fisher
 * see LICENSE
 */
%%{
  machine esi_choose;

	action esi_choose_open {
		printf( "choose open\n" );
	}

	action esi_choose_close {
		printf( "choose close\n" );
	}
  
  action esi_otherwise_open {
    m_active_buffer = 3;
		printf("open otherwise\n");
  }

  action esi_otherwise_close {
    this->prune_seq("</esi:otherwise");
    m_active_buffer = 0;
		printf("close otherwise\n");
  }

  action esi_when_open {
    m_active_buffer = 3;
    printf("open when\n");
  }
  action esi_when_close {
    this->prune_seq("</esi:when");
    m_active_buffer = 0;
    printf("close when\n");
  }
  action esi_when_test {
    printf("when test\n");
  }

  action esi_choose_complete {
    printf("when buffer: %s\n", m_choose.c_str());
    fret;
  }

  action esi_choose_error {
    m_active_buffer = 0;
    fhold;
    printf( "ERROR parsing esi choose at char: %c\n", *p );
    fret;
  }

  action esi_choose_buffer {
    this->append_char(*p);
  }

  esi_choose_machine := (
      (space* '<esi:when' space+ 'test' space* '='
                          @esi_when_test space* esi_test space* '>' %esi_when_open
                ( esi_basic_tags | any@esi_choose_buffer )* :>>'</esi:when>' @esi_when_close )+
      (space* '<esi:otherwise>' %esi_otherwise_open
                ( esi_basic_tags | any@esi_choose_buffer )* :>>'</esi:otherwise>' %esi_otherwise_close)? space*
    '</esi:choose>' @esi_choose_complete
  ) @!esi_choose_error;

  action esi_choose_begin {
    fcall esi_choose_machine;
  }
 
  esi_choose = (
    '<esi:choose>' %esi_choose_begin
  );
}%%
