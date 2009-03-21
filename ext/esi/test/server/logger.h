#ifndef SIPHON_LOGGER_H
#define SIPHON_LOGGER_H

#include "config.h"
#include <stdio.h>

namespace Siphon {

  struct Logger {
    enum Level {
      SILENT = 0,
      ERROR = 1,
      INFO = 2,
      WARN = 3,
      DEBUG = 4
    };

    Logger(const char *logfile, Level level = INFO);
    ~Logger();

    static Level level_from_string( const char *str );

    void log(Level level, const char *msg, ...);
    void debug( const char *msg, ... );
    void error( const char *msg, ... );
    void info( const char *msg, ... );
    void warn( const char *msg, ... );

    void log_level(Level l) { m_active_level = l; }

  private:
    Level m_active_level;
    FILE *m_log_file;
  };

}

#endif
