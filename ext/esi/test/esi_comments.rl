/** 
 * Copyright (c) 2008 Todd A. Fisher
 * see LICENSE
 */
%%{
  machine esi_comments;
  
  action esi_comment_start  {
    this->prune_seq("<!--esi");
		printf("esi start comment\n");
    m_comment = true;
    fcall main;
  }
  
  action esi_check_comment {
    if( m_comment ) {
      printf("esi end comment\n");
      this->prune_seq("-->");
      m_comment = false;
      fret;
    }
    else {
      this->append_char(*p);
    }
		printf("esi end comment\n");
  }

  action esi_comment_done {
    printf( "comment done\n");
    fret;
  }
  action esi_comment_error {
    fhold;
    printf("ESI COMMENT ERROR: %c\n", *p);
    fret;
  }

  esi_comment_machine := (
    space* 'text' space* '=' (( '"' ("\\\""|[^"])* :>> '"' ) | 
                              ( "'" ("\\\'"|[^'])* :>> "'" ) ) '/>' @esi_comment_done
  ) @!esi_comment_error;

  action esi_comment_begin {
    this->prune_seq("<esi:comment");
    fcall esi_comment_machine;
  }

	esi_comment = (
     '<esi:comment' space @esi_comment_begin
  );

  esi_html_comment = (
    '<!--esi' @esi_comment_start
  );

}%%
