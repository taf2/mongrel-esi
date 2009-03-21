/** 
 * Copyright (c) 2008 Todd A. Fisher
 * see LICENSE
 */
%%{
  machine esi_invalidate;

  action esi_invalidate_complete {
    printf( "esi invalidate complete\n" );
    fret;
  }

  action esi_invalidate_error {
    fhold;
    printf( "ERROR: esi invalidate parse error at: %c\n", *p );
    fret;
  }

  action buffer_invalidate {
  }


  esi_invalidate_machine := (
    (any@buffer_invalidate)* :>> '</esi:invalidate>' @esi_invalidate_complete
  ) @!esi_invalidate_error;

  action esi_invalidate_begin {
    this->prune_seq("<esi:invalidate>");
    printf("invalidate begin\n");
    fcall esi_invalidate_machine;
  }

	esi_invalidate = (
		'<esi:invalidate>' %esi_invalidate_begin
	);
}%%
