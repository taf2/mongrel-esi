CFLAGS=-g -Wall -O0 #-fprofile-arcs -ftest-coverage
RAGEL_FILES=esi_common.rl\
						esi_include.rl\
						esi_inline.rl\
						esi_vars.rl\
						esi_expr.rl\
						esi_comments.rl\
						esi_invalidate.rl\
						esi_choose.rl\
						esi_try.rl
TEST_FILES=esi_include_test.rl

all: esi
	./esi
testit: parser.o test.o
	$(CC) $(CFLAGS) -o $@ $^

time: all
	time ./testit
valgrind: all
	valgrind --leak-check=full ./testit
test.o: test.c parser.h
	$(CC) $(CFLAGS) test.c -c
parser.o: parser.c parser.h
	$(CC) $(CFLAGS) parser.c -c
parser.c: parser.rl parser.h common.rl
	#ragel parser.rl | rlgen-cd -G1 -o parser.c 
	ragel -e -G1 parser.rl  -o parser.c
	wc -l parser.c


esi.cc: esi.rl $(RAGEL_FILES) esi.h
	ragel -G2 -s $<  -o $@
esi.o: esi.cc esi.h
	$(CXX) $(CFLAGS) $^ -c
scanner.o: scanner.cc esi.h
esi_test.o: esi_test.cc esi.h
	$(CXX) $(CFLAGS) $^ -c
esi: esi_test.o esi.o scanner.o
	$(CXX) $(CFLAGS) -o $@ $^

esi_include_test.cc: esi_include_test.rl
	ragel -G2 -s $^ -o $@
esi_parse_test.o: esi_parse_test.cc $(RAGEL_FILES) esi.h esi_test_base.h
	$(CXX) $(CFLAGS) $< -c
esi_include_test.o: esi_include_test.cc $(RAGEL_FILES) esi.h esi_test_base.h
	$(CXX) $(CFLAGS) $< -c
esi_include_test: esi_include_test.o esi_parse_test.o
	$(CXX) $(CFLAGS) -o $@ $^

test: esi_include_test
	./esi_include_test

esi_include.dot: esi_include_test.rl esi_include.rl esi_common.rl
	ragel -V $< -o $@
esi_include.png: esi_include.dot
	dot -Tpng $< -o $@
esi2.dot: esi.rl esi_common.rl esi_include.rl
	ragel -V $< -o $@
esi2.png: esi2.dot
	dot -Tpng $< -o $@

parser.h: setup
parser.rl: setup

setup:
	ln -fs ../parser.h
	ln -fs ../parser.c
	ln -fs ../parser.rl
	ln -fs ../common.rl

clean:
	rm -f parser.c parser.o test.o testit esi esi.cc esi_include_test.cc esi_include.cc
