#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <regex.h>
#include <fcntl.h>
#include <unistd.h> /* for write */
#define DEBUG
#include "parser.h"

#ifdef DEBUG
#define TRACE()  fprintf(stderr, "> %s:%d:%s\n", __FILE__, __LINE__, __FUNCTION__)
#else
#define TRACE() 
#endif


/*
 * TagInfo is used for collecting tags and asserting we have generated the correct tag names
 */
typedef struct _TagInfo {
  char *name;
  ESIAttribute *attributes;
  struct _TagInfo *next;
}TagInfo;

static
TagInfo* tag_info_new( const char *name, size_t len, ESIAttribute *attributes )
{
  TagInfo *ti = (TagInfo*)malloc(sizeof(TagInfo));
  ti->name = esi_strndup( name, len );
  ti->attributes = esi_attribute_copy( attributes );
  ti->next = NULL;
  return ti;
}

static
void tag_info_show( TagInfo *ti )
{
  char buffer1[1024], buffer2[1024];
  ESIAttribute *attrs = ti->attributes;
  if( attrs ) {
    printf("%s{", ti->name );
    while( attrs ) {
      memcpy( buffer1, attrs->name, attrs->name_length );
      buffer1[attrs->name_length] = '\0';
      memcpy( buffer2, attrs->value, attrs->value_length );
      buffer2[attrs->value_length] = '\0';
      printf( "(%s=>%s),", buffer1, buffer2 );
      attrs = attrs->next;
    }
    printf("}\n");
  }
  else {
    printf("%s\n", ti->name );
  }
}

static
void tag_info_free( TagInfo *ti )
{
  TagInfo *ptr = NULL;
  while( ti ){
    free( ti->name );
    if( ti->attributes ) esi_attribute_free( ti->attributes );
    ptr = ti->next; /* save the next pointer */
    free( ti );
    ti = ptr;
  }
}

static int verify_string( const char *str, const char *str_value, int line, const char *test_name )
{
  int str_len = strlen( str );
  int str_value_length = strlen( str_value ); 

  if( str_len != str_value_length || strcmp( str, str_value ) ){
    printf( "Strings are not equal\n\t\"%s\":%d\n!=\t\n\"%s\":%d\nat\n%s:%d\n", str, str_len, str_value, str_value_length, test_name, line );
    return 1;
  }
  return 0;
}

static int verify_match_string( const char *expr, const char *str_value, int line, const char *test_name )
{
  int status;
  regex_t reg_expr;
  regcomp( &reg_expr, expr, REG_EXTENDED|REG_NOSUB );
  status = regexec( &reg_expr, str_value, (size_t) 0, NULL, 0 );
  regfree( &reg_expr );
  if( status != 0 ){
    printf( "No matching %s expression found in '%s' at %s:%d \n", expr, str_value, test_name, line );
    return 1;
  }
  return 0;
}

static int verify_no_match_string( const char *expr, const char *str_value, int line, const char *test_name )
{
  int status;
  regex_t reg_expr;
  regcomp( &reg_expr, expr, REG_EXTENDED|REG_NOSUB );
  status = regexec( &reg_expr, str_value, (size_t) 0, NULL, 0 );
  regfree( &reg_expr );
  if( status == 0 ){
    printf( "Found matching %s expression found in '%s' at %s:%d ", expr, str_value, test_name, line );
    return 1;
  }
  return 0;
}

static int verify_true( int expr, int line, const char *test_name )
{
  if( !expr ){
    printf( "Expression is not true at %s:%d\n", test_name, line );
    return 1;
  }
  return 0;
}

static int start_tag_count = 0;
static int end_tag_count = 0;
static TagInfo *detected_start_tags = NULL; /* store parsed start tags from each test */
static TagInfo *detected_end_tags = NULL; /* store parsed end tags from each test */

static
TagInfo *add_detected_tag( TagInfo *tags, TagInfo *ti )
{
  if( tags ){
    TagInfo *next = tags;
    TagInfo *prev = NULL;
    while( next ){
      prev = next;
      next = next->next;
    }
    prev->next = ti;
  }
  else{
    tags = ti;
  }
  return tags;
}

static 
void free_detected_tags()
{
  if( detected_start_tags ){
    tag_info_free( detected_start_tags );
  }
  if( detected_end_tags ){
    tag_info_free( detected_end_tags );
  }
  detected_end_tags = NULL;
  detected_start_tags = NULL;
}

static void start_tag_handler( const void *data,
                               const char *name_start,
                               size_t name_length,
                               ESIAttribute *attributes,
                               void *user_data )
{
  ++start_tag_count;
  detected_start_tags = add_detected_tag( detected_start_tags, tag_info_new( name_start, name_length, attributes ) );
}
static void end_tag_handler( const void *data,  const char *name_start, size_t name_length, void *user_data )
{
  ++end_tag_count;
  detected_end_tags = add_detected_tag( detected_end_tags, tag_info_new( name_start, name_length, NULL ) );
}

static void output_handler( const void *data, size_t size, void *user_data )
{
  write( (*(int*)user_data), data, size );
}

static void feed_data( ESIParser *parser, const char *data )
{
//  printf( "feeding: %s\n", data );
  esi_parser_execute( parser, data, strlen(data) );
}

#define TEST_INIT \
  int fd;  \
  struct stat st;  \
  char *output = NULL;  \
  size_t output_size;  \
  int status = 0;\
  start_tag_count = 0; \
  end_tag_count = 0; \
  printf( "%s: ", __FUNCTION__ ); \
  esi_parser_init( parser ); \
 \
  esi_parser_start_tag_handler( parser, start_tag_handler ); \
  esi_parser_end_tag_handler( parser, end_tag_handler ); \
 \
  unlink( "output.html" ); \
  fd = open( "output.html", O_WRONLY | O_CREAT | O_TRUNC, S_IRUSR | S_IWUSR | S_IRGRP | S_IROTH);  \
  parser->user_data = (void*)(&fd); \
  esi_parser_output_handler( parser, output_handler );

#define TEST_WITH_FILE(file)\
  int size = 0;\
  FILE *input = NULL;\
  char buffer[4096]; \
  TEST_INIT\
\
  input = fopen( file, "r" );\
  if( !input ){\
    printf( "Failed to open %s\n", file );\
    return;\
  }\
\
  while( (size = fread( buffer, sizeof(char), 4095, input )) > 0 ){\
    esi_parser_execute( parser, buffer, size );\
  }\
\
  fclose( input );

#define TEST_PREPARE_ASSERTIONS \
  esi_parser_finish( parser ); \
 \
  close( fd ); \
 \
  fd = open( "output.html", O_RDONLY ); \
  fstat( fd, &st ); \
  output_size = st.st_size; \
  output = (char*)malloc(sizeof(char)*(output_size+1)); \
  read( fd, output, output_size ); \
  output[output_size] = '\0'; \
  close( fd ); \
  TagInfo *start_tags = detected_start_tags; \
  TagInfo *end_tags = detected_end_tags;

#define TEST_FINISH\
  free( output ); \
  free_detected_tags(); \
  if( status ){ \
    printf( "FAILED\n" ); \
  }else{ \
    printf( "PASSED\n" ); \
  }
#define ASSERT_EQUAL( s1, s2 )\
  status |= verify_string( s1, s2, __LINE__, __FUNCTION__ )

#define ASSERT_MATCH( regex, str )\
  status |= verify_match_string( regex, str, __LINE__, __FUNCTION__ )
#define ASSERT_NO_MATCH( regex, str )\
  status |= verify_no_match_string( regex, str, __LINE__, __FUNCTION__ )
#define ASSERT_TRUE( expr )\
  status |= verify_true( expr, __LINE__, __FUNCTION__ )

#define ASSERT_TAG_NAME( name )\
  ASSERT_NO_MATCH( "<", name ); \
  ASSERT_MATCH( "esi:", name );

#define ASSERT_TAG_NAMES( tags )\
  while( tags  ){ \
    ASSERT_TAG_NAME( tags->name );\
    tags = tags->next;\
  }

static void test_simple_parser_input( ESIParser *parser )
{
  TEST_INIT

  feed_data( parser, "<p>some input</p><esi:include />some more input\nsome input<esi:include timeout='10' src='hello'/>some more input" );

  TEST_PREPARE_ASSERTIONS

  ASSERT_EQUAL( "<p>some input</p>some more input\nsome inputsome more input", output );
  ASSERT_TRUE( start_tag_count == 2 );
  ASSERT_TRUE( end_tag_count == 2 );
  
  ASSERT_TAG_NAMES( start_tags )
  ASSERT_TAG_NAMES( end_tags )

  TEST_FINISH
}

static void test_small_buffer( ESIParser *parser )
{
  const int input_size = 2;
  const char *input = "<p>some input</p><esi:include />some more input\nsome input<esi:include timeout='10' src='hello'/>some more input";
  int i, len = strlen(input);

  TEST_INIT
//  printf("\n");

  for( i = 0; i < len; i += input_size ) {
    if( i + input_size <= len ) {
      esi_parser_execute( parser, (input+i), input_size );
    }
    else {
      esi_parser_execute( parser, (input+i), len - i );
    }
  }

  TEST_PREPARE_ASSERTIONS

  ASSERT_EQUAL( "<p>some input</p>some more input\nsome inputsome more input", output );
  ASSERT_TRUE( start_tag_count == 2 );
  ASSERT_TRUE( end_tag_count == 2 );
  
  ASSERT_TAG_NAMES( start_tags )
  ASSERT_TAG_NAMES( end_tags )

  TEST_FINISH
}

static void test_chunked_input( ESIParser *parser )
{
  TEST_INIT

  feed_data( parser, "some input<" );
  feed_data( parser, "e" );
  feed_data( parser, "s" );
  feed_data( parser, "i" );
  feed_data( parser, ":" );
  feed_data( parser, "i" );
  feed_data( parser, "n" );
  feed_data( parser, "lin" );
  feed_data( parser, "e" );
  feed_data( parser, " " );
  feed_data( parser, "s" );
  feed_data( parser, "rc" );
  feed_data( parser, "=" );
  feed_data( parser, "'hel" );
  feed_data( parser, "lo'" );
  feed_data( parser, "/" );
  feed_data( parser, ">some more input\nsome input" );
  feed_data( parser, "<esi:comment text=" );
  feed_data( parser, "'hello'/>some more input" );
 
  TEST_PREPARE_ASSERTIONS

  ASSERT_EQUAL( "some inputsome more input\nsome inputsome more input", output );
  ASSERT_TRUE( start_tag_count == 2 );
  ASSERT_TRUE( end_tag_count == 2 );
  
  ASSERT_TAG_NAMES( start_tags )
  ASSERT_TAG_NAMES( end_tags )

  TEST_FINISH
}
#define ESI_SAMPLE "../../../test/unit/esi-sample.html" 
static void test_sample_input( ESIParser *parser )
{
  TEST_WITH_FILE( ESI_SAMPLE );

  TEST_PREPARE_ASSERTIONS

  ASSERT_MATCH("  <div class=\"body\">", output );
  ASSERT_MATCH("    <div>some content</div>", output);
  ASSERT_MATCH("<em>Support for em tags since they have an initial start sequence similar to and &lt;esi: start/end sequence</em>", output );
  ASSERT_NO_MATCH("<esi:", output);
/*
  TagInfo *ptr = start_tags;

  while( ptr  ){ 
    tag_info_show( ptr );
    ptr = ptr->next;
  }

  printf( "start_tag_count: %d\n", start_tag_count );
  printf( "end_tag_count: %d\n", end_tag_count );
  */

  ASSERT_TRUE( start_tag_count == 13 );
  ASSERT_TRUE( end_tag_count == 13 );

  ASSERT_TAG_NAMES( start_tags )
  ASSERT_TAG_NAMES( end_tags )

  TEST_FINISH
}

static void test_line_by_line( ESIParser *parser )
{
  TEST_INIT

  feed_data( parser, "<html><head><body><esi:include timeout='1' max-age='600+600' src=\"hello\"/>some more input" );
  feed_data( parser, "some input<esi:include \nsrc='hello'/>some more input\nsome input<esi:include src=\"hello\"/>some more input" );
  feed_data( parser, "some input<esi:inline src='hello'/>some more input\nsome input<esi:comment text='hello'/>some more input" );
  feed_data( parser, "<p>some input</p><esi:include src='hello'/>some more input\nsome input<esi:include src='hello'/>some more input" );
  feed_data( parser, "</body></html>" );

  TEST_PREPARE_ASSERTIONS

  ASSERT_EQUAL("<html><head><body>some more inputsome inputsome more input\nsome inputsome more inputsome inputsome more input\nsome inputsome more input<p>some input</p>some more input\nsome inputsome more input</body></html>", output );
  ASSERT_TRUE( start_tag_count == 7 );
  ASSERT_TRUE( end_tag_count == 7 );
  
  ASSERT_TAG_NAMES( start_tags )
  ASSERT_TAG_NAMES( end_tags )

  TEST_FINISH
}

#define ESI_LARGE_FILE "../../../test/integration/docs/index.html" 
static void test_large_file( ESIParser *parser )
{
  TEST_WITH_FILE( ESI_LARGE_FILE );

  TEST_PREPARE_ASSERTIONS

  ASSERT_NO_MATCH("<esi:", output);

  ASSERT_MATCH( "</html>", output );

  ASSERT_TAG_NAMES( start_tags )
  ASSERT_TAG_NAMES( end_tags )

  TEST_FINISH
}

static void test_sample1( ESIParser *parser )
{
  TEST_WITH_FILE( "sample1.html" );

  TEST_PREPARE_ASSERTIONS

//  ASSERT_MATCH("YYY", output);
  //ASSERT_NO_MATCH("failed", output );
  ASSERT_NO_MATCH("<esi:", output);
  ASSERT_MATCH("<html", output);
  ASSERT_MATCH("</html>", output);
  ASSERT_MATCH("line 1: <pre>", output);
  ASSERT_MATCH("line 2: <pre>", output);
  ASSERT_MATCH("line 3: <pre>", output);
  ASSERT_MATCH("line 4: <pre>", output);
  ASSERT_MATCH("line 5: <pre>", output);
  ASSERT_MATCH("line 6: <pre>", output);
  ASSERT_MATCH("line 7: <pre>", output);
  ASSERT_MATCH("line 8: <pre>", output);
  ASSERT_MATCH("line 9: <pre>", output);


  /*
  TagInfo *ptr = start_tags;
  while( ptr  ) { 
    tag_info_show( ptr );
    ptr = ptr->next;
  }
  printf( "start_tag_count: %d\n", start_tag_count );
  printf( "end_tag_count: %d\n", end_tag_count );
  */
 

  ASSERT_TRUE( start_tag_count == 30 );
  ASSERT_TRUE( end_tag_count == 30 );

  ASSERT_TAG_NAMES( start_tags )
  ASSERT_TAG_NAMES( end_tags )

  TEST_FINISH
}
#if 0
static void test_sample1_with_chunking( ESIParser *parser )
{
  TEST_WITH_FILE( "sample1.html" );

  TEST_PREPARE_ASSERTIONS

//  ASSERT_MATCH("YYY", output);
  ASSERT_NO_MATCH("failed", output );
  ASSERT_NO_MATCH("<esi:", output);

  /*TagInfo *ptr = start_tags;
  while( ptr  ) { 
    tag_info_show( ptr );
    ptr = ptr->next;
  }
  printf( "start_tag_count: %d\n", start_tag_count );
  printf( "end_tag_count: %d\n", end_tag_count );
  */

  ASSERT_TRUE( start_tag_count == 23 );
  ASSERT_TRUE( end_tag_count == 16 );

  ASSERT_TAG_NAMES( start_tags )
  ASSERT_TAG_NAMES( end_tags )

  TEST_FINISH
}
#endif

static void test_large_chunked_file( ESIParser *parser );

static void test_large_with_two_chunks( ESIParser *parser );

static void run_parser_through_all()
{
  ESIParser *parser = esi_parser_new();
  printf( "%s\n", __FUNCTION__ );

  test_simple_parser_input( parser );

  test_small_buffer( parser );

  test_chunked_input( parser );

  test_sample_input( parser );

  test_line_by_line( parser );
  
  test_large_file( parser );

  test_large_chunked_file( parser );

  test_sample1( parser );

  test_large_with_two_chunks( parser );

  esi_parser_free( parser );
}

int main( int argc, char **argv )
{
  run_parser_through_all();
  return 0;
}

static void test_large_with_two_chunks( ESIParser *parser )
{
  int size1 = 0;
  int size2 = 0;
  FILE *input = NULL;
  char *chunk1 = NULL;
  char *chunk2 = NULL;
  
  TEST_INIT

  input = fopen( "chunk1.html", "rb" );
  if( !input ) {
    printf( "Failed to open %s\n", "chunk1.html" );
    return;
  }
 
  fstat( fileno(input), &st );

  chunk1 = (char*)malloc(sizeof(char)*st.st_size);

  size1 = fread( chunk1, sizeof(char), st.st_size, input );
  if( size1 != st.st_size ) {
    printf( "Read error\n" );
    return;
  }

  fclose(input);

  input = fopen( "chunk2.html", "rb" );
  if( !input ) {
    printf( "Failed to open %s\n", "chunk2.html" );
    return;
  }
 
  fstat( fileno(input), &st );

  chunk2 = (char*)malloc(sizeof(char)*st.st_size);

  size2 = fread( chunk2, sizeof(char), st.st_size, input );
  if( size2 != st.st_size ) {
    printf( "Read error\n" );
    return;
  }

  fclose(input);
 
  esi_parser_execute( parser, chunk1, size1 );
  esi_parser_execute( parser, chunk2, size2 );
 
  TEST_PREPARE_ASSERTIONS

  ASSERT_NO_MATCH("<esi:", output);

  ASSERT_MATCH( "</html>", output );

  ASSERT_TAG_NAMES( start_tags )
  ASSERT_TAG_NAMES( end_tags )


  TEST_FINISH
}

#define ESI_LARGE_FILE_CHUNKED "chunks.txt" 
static void test_large_chunked_file( ESIParser *parser )
{
  int size = 0;
  FILE *input = NULL;
  char *buffer = NULL;
  char *chunk_start = NULL;
  char *chunk_end = NULL;
  char *buffer_end = NULL;

  TEST_INIT
  
//  printf( "\n" );

  input = fopen( ESI_LARGE_FILE_CHUNKED, "r" );
  if( !input ){
    printf( "Failed to open %s\n", ESI_LARGE_FILE_CHUNKED );
    return;
  }

  fstat( fileno(input), &st );

  buffer = (char*)malloc(sizeof(char)*st.st_size);

  size = fread( buffer, sizeof(char), st.st_size, input );
  if( size != st.st_size ) {
    printf( "Read error\n" );
    return;
  }
  buffer_end = buffer + size;

  for( chunk_start = buffer; chunk_start != buffer_end; ) {
    while( chunk_start != buffer_end && *chunk_start != '{' ) { ++chunk_start; }
    if( chunk_start == buffer_end ){ break; }
    chunk_end = chunk_start;
    while( chunk_end != buffer_end && *chunk_end != '}' ) { ++chunk_end; }
    ++chunk_start;
    if( chunk_start > buffer_end ){ break; }

    if( (chunk_end - chunk_start) > 0 ) {
      esi_parser_execute( parser, chunk_start, chunk_end - chunk_start );
      chunk_start = chunk_end;
    }
  }

  fclose( input );
  free( buffer );

  TEST_PREPARE_ASSERTIONS

  ASSERT_NO_MATCH("<esi:", output);

  ASSERT_MATCH( "</html>", output );

  ASSERT_TAG_NAMES( start_tags )
  ASSERT_TAG_NAMES( end_tags )

  TEST_FINISH
}
