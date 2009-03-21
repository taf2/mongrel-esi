/** 
 * Copyright (c) 2008 Todd A. Fisher
 * see LICENSE
 */
%%{
  machine esi_remove;
 
	action scan_for_remove_close {
  }

  esi_remove = (
    '<esi:remove>' @scan_for_remove_close '</esi:remove'
  );
  
}%%
