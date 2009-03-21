require 'mkmf'

$CPPFLAGS="-Wall"

dir_config("esi")
have_library("c", "main")

create_makefile("esi")
