#!/bin/sh

exec valgrind --leak-check=full --suppressions=valgrind-ruby.supp ruby test2.rb
