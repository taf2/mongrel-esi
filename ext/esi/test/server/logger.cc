#include "logger.h"
#include <string.h>
#include <stdarg.h>
#include "types.h"

namespace Siphon {

Logger::Logger(const char *logfile, Level level)
{
  m_log_file = fopen(logfile,"a+");
  m_active_level = level;
  if( !m_log_file ) {
    perror(("Failed to open logfile: " + String(logfile)).c_str());
    exit(EXIT_FAILURE);
  }
}

Logger::~Logger()
{
  fflush(m_log_file);
  fclose(m_log_file);
}


void Logger::debug( const char *msg, ... )
{
  if( DEBUG <= m_active_level ) {
    va_list ap;
    va_start( ap, msg );
    vfprintf(m_log_file,msg,ap);
    va_end(ap);
    fflush(m_log_file);
  }
}
void Logger::error( const char *msg, ... )
{
  if( ERROR <= m_active_level ) {
    va_list ap;
    va_start( ap, msg );
    vfprintf(m_log_file,msg,ap);
    va_end(ap);
    fflush(m_log_file);
  }
}
void Logger::info( const char *msg, ... )
{
  if( INFO <= m_active_level ) {
    va_list ap;
    va_start( ap, msg );
    vfprintf(m_log_file,msg,ap);
    va_end(ap);
    fflush(m_log_file);
  }
}
void Logger::warn( const char *msg, ... )
{
  if( WARN <= m_active_level ) {
    va_list ap;
    va_start( ap, msg );
    vfprintf(m_log_file,msg,ap);
    va_end(ap);
    fflush(m_log_file);
  }
}

void Logger::log(Level level, const char *msg, ...)
{
  if( level <= m_active_level ) {
    va_list ap;
    va_start( ap, msg );
    vfprintf(m_log_file,msg,ap);
    va_end(ap);
    fflush(m_log_file);
  }
}

Logger::Level Logger::level_from_string( const char *str )
{
  if( !strcmp( str, "debug" ) ) {
    return DEBUG;
  }
  else if( !strcmp( str, "info" ) ) {
    return INFO;
  }
  else if( !strcmp( str, "warn" ) ) { 
    return WARN;
  }
  else if( !strcmp( str, "error" ) ) {
    return ERROR;
  }
  else {
    // TODO: what log level??
    return DEBUG; // they probably need it
  }
}

}
