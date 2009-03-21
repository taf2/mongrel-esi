/* Copyright (c) 2008 Todd A. Fisher */
#include "config.h"
#include <stdio.h>
#include <stdlib.h>
#include <signal.h>
#include <setjmp.h>
#include <errno.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <unistd.h>
#include <pwd.h>
#ifdef HAVE_LIBGEN_H
#include <libgen.h> // included for dirname
#endif
#include "server.h"

Siphon::Logger *glogger = NULL;

static jmp_buf g_term_env;
static jmp_buf g_recover_env;

static void recover_handler(int signum, siginfo_t *info)
{
#ifdef IS_DARWIN 
  glogger->error("sig %d => %s\n", signum, sys_signame[signum] );
#else
  glogger->error("sig %d\n", signum );
#endif
  glogger->error("si_signo %d si_errno %d si_code %d\n", info->si_signo, info->si_errno, info->si_code);
  switch (signum) {
  case SIGFPE:
  case SIGBUS:
  case SIGILL:
  case SIGSEGV:
    glogger->error("si_addr %08lx", (unsigned long)info->si_addr);
#ifdef __sparc__
    glogger->error(" si_trapno %08x", *(int *)((&info->si_addr)+1));
#endif
    glogger->error("\n");
    break;
#ifdef HAVE_SIGINFO_TIMERS
  case SIGCHLD:
    glogger->error("si_pid %d si_uid %d si_status %d\n", info->si_pid, info->si_uid, info->si_status);
    glogger->error("si_utime %ld si_stime %ld", info->si_utime, info->si_stime);
#ifdef __i386__
    glogger->error(" si_uid32 %d", ((unsigned int *)&info->si_stime)[1]);
#endif
    glogger->error("\n");
#endif
  }
  siglongjmp( g_recover_env, 1 );
}

static void term_handler(int signum, siginfo_t *info)
{
#ifdef IS_DARWIN 
  glogger->info("sig %d => %s\n", signum, sys_signame[signum] );
#else
  glogger->info("sig %d\n", signum );
#endif
  glogger->info("si_signo %d si_errno %d si_code %d\n", info->si_signo, info->si_errno, info->si_code);
  switch (signum) {
  case SIGFPE:
  case SIGBUS:
  case SIGILL:
  case SIGSEGV:
    glogger->info("si_addr %08lx", (unsigned long)info->si_addr);
#ifdef __sparc__
    glogger->info(" si_trapno %08x", *(int *)((&info->si_addr)+1));
#endif
    glogger->info("\n");
    break;
#ifdef HAVE_SIGINFO_TIMERS
  case SIGCHLD:
    glogger->info("si_pid %d si_uid %d si_status %d\n", info->si_pid, info->si_uid, info->si_status);
    glogger->info("si_utime %ld si_stime %ld", info->si_utime, info->si_stime);
#ifdef __i386__
    glogger->info(" si_uid32 %d", ((unsigned int *)&info->si_stime)[1]);
#endif
    glogger->info("\n");
#endif
  }
  siglongjmp( g_term_env, 1 );
}

static
int set_signal(int sig, const char*name, void(*handler)(int) )
{
  struct sigaction sa;
  sa.sa_handler = handler;
  sigemptyset(&sa.sa_mask);
  sa.sa_flags = SA_SIGINFO;

  if (sigaction(sig, &sa, NULL) < 0) {
    glogger->error("sigaction(%s): '%s'", name, strerror(errno) );
    return 1;
  }
  return 0;
}
//
// seems to be the best example i could find for learning signals:
// http://support.sas.com/documentation/onlinedoc/sasc/doc700/html/lr1/z2056472.htm
//
#define set_term_signal(sig,name) set_signal(sig,name,(void (*)(int))&term_handler)
static int set_term_signals()
{
  int r = 0;
  r += set_term_signal(SIGSEGV,"segv");
#ifdef HAVE_SIGSTKFLT
  r += set_term_signal(SIGSTKFLT,"stkflt");
#endif
  r += set_term_signal(SIGTERM,"term");
  r += set_term_signal(SIGINT,"int");
  return r;
}

static int set_recover_signals()
{
  int r = 0;
#ifdef SIGUNUSED
  for( int i = SIGHUP; i < SIGUNUSED; ++i ) {
#else
  for( int i = SIGHUP; i < SIGUSR1; ++i ) {
#endif
    switch(i){
    case SIGSEGV:
#ifdef HAVE_SIGSTKFLT
    case SIGSTKFLT:
#endif
    case SIGKILL:
    case SIGTERM:
    case SIGINT:
    case SIGPIPE:
    case SIGSTOP: // not catchable
      continue;
    default:
      set_signal(i,"", (void (*)(int))recover_handler);
    }
  }

  return r;
}

// monitor the number of open sockets
namespace Siphon {
  extern int allocated_sockets;
}

static
void parse_options(int& argc, char**& argv, Siphon::ConfigMap& options)
{
  int ch;
  while ((ch = getopt(argc, argv, "dhc:")) != -1) {
    switch(ch) {
    default:
    case 'h': // help requested
      fprintf(stderr,"usage: %s -c path_to_siphon_config\n", __FILE__);
      break;
    case 'd':
      options["daemonize"] = "true";
      break;
    case 'c': // config path
      options["config"] = optarg;
      break;
    }
  }
  argc -= optind;
  argv += optind;
}

static 
void daemonize()
{
  // see: http://www.netzmafia.de/skripten/unix/linux-daemon-howto.html
  int fd;
  pid_t pid, sid;

  // Fork off the parent process
  pid = fork();
  if (pid < 0) {
    perror("Failed to daemonize while forking from parent");
    exit(EXIT_FAILURE);
  }

  // If we got a good PID, then
  // we can exit the parent process.
  if (pid > 0) {
    exit(EXIT_SUCCESS);
  }

  // Change the file mode mask
  umask(0);       
  
  // Open any logs here
  
  // Create a new SID for the child process
  sid = setsid();
  if (sid < 0) {
    // Log any failures here
    perror("Failed to daemonize while setting child session");
    exit(EXIT_FAILURE);
  }
  
  // Change the current working directory
  if ((chdir("/")) < 0) {
    // Log any failures here
    perror("Failed to daemonize while changing to /");
    exit(EXIT_FAILURE);
  }

  fflush(stdin);
  fflush(stdout);
  fflush(stderr);

  // see: http://code.sixapart.com/trac/memcached/browser/branches/facebook/daemon.c?rev=288
  fd = open("/dev/null",O_RDWR,0);
  if( fd != -1 ) {
    dup2(fd, STDIN_FILENO);
    dup2(fd, STDOUT_FILENO);
    dup2(fd, STDERR_FILENO);
    if( fd > STDERR_FILENO ) {
      close(fd);
    }
  }
  else {
    // Close out the standard file descriptors
    close(STDIN_FILENO);
    close(STDOUT_FILENO);
    close(STDERR_FILENO); 
  }
}

static 
int runServer( Siphon::ConfParser &config, Siphon::ConfigMap &options )
{
  Siphon::HttpServer *server = new Siphon::HttpServer(config);

  glogger->info( "Setting server signal mask\n" );
  set_term_signals();

  if( sigsetjmp( g_term_env, 1 ) ) {
    glogger->info( "stopping the server\n" );
    server->stop();
  }
  else {
    glogger->info( "recover signals\n" );

    set_recover_signals();
    glogger->info( "enable server\n" );
    server->enable();
    glogger->info( "mark server jump\n" );
    sigsetjmp( g_recover_env, 1 );

    glogger->info( "run server\n" );
    server->run();
  }

  glogger->info("exiting cleanly with: %d open sockets\n", Siphon::allocated_sockets );
  delete server;
  return 0;
}
static void current_path_str( Siphon::String &pwd )
{
#ifdef HAVE_LIBGEN_H
  char *buf = strdup(pwd.c_str());
  char *dir = dirname(buf);
  pwd = dir;
  free(buf);

  if( pwd[0] != '/' ) { 
    char pbuf[1024];
    // pwd isn't an absolute path so we need to make it one
    if( !getcwd(pbuf,1024) ) {
      perror("Failed to get the current working directory");
      exit(EXIT_FAILURE);
    }
    if( pwd[0] == '.' ) {
      pwd.erase(0,1);
    }
    if( pwd[0] != '/' ) {
      pwd = Siphon::String(pbuf) + "/" + pwd;
    }
    else {
      pwd = pbuf + pwd;
    }
  }
#else
  // TODO: no dirname on this OS??
#endif
}

int main( int argc, char **argv )
{
  int r = 1;
  Siphon::String pwd(argv[0]);
  Siphon::ConfigMap options;

  parse_options(argc, argv, options);

  // get the startup path, used if paths in config file are relative
  current_path_str( pwd );

  Siphon::ConfParser config(pwd);

  config.load(options["config"].c_str());
    
  Siphon::String logfile = config.get_core_path("logfile","/var/log/siphon/siphon.log");
  Siphon::Logger::Level default_level = Siphon::Logger::level_from_string(config.get_core_str("loglevel","info").c_str() );

  glogger = new Siphon::Logger( logfile.c_str(), default_level );

  if( options["daemonize"] == "true" ) {
    daemonize();
    // switch the running process user 
    Siphon::String run_user = config.get_core_str("user");

    if( !run_user.empty() ) {
      struct passwd *pwd = getpwnam(run_user.c_str());
      if( !pwd ) {
        glogger->error("Failed to set daemon user: %s\n", run_user.c_str());
        delete glogger;
        exit(EXIT_FAILURE);
      }
      if( setuid(pwd->pw_uid) ) {
        glogger->error("Failed to set daemon user: %s\n", run_user.c_str());
        delete glogger;
        exit(EXIT_FAILURE);
      }

      if( setgid(pwd->pw_gid) ) {
        glogger->error("Failed to set daemon group for: %s\n", run_user.c_str());
        delete glogger;
        exit(EXIT_FAILURE);
      }
    }

    // save the pidfile
    Siphon::String pidfile = config.get_core_path("pidfile","/var/log/siphon/siphon.pid");
    pid_t pid = getpid();

    glogger->info("Starting server with pid: %d\n", pid );

    // save the process pid
    int fd = open( pidfile.c_str(), O_WRONLY | O_TRUNC | O_CREAT, 0666 );
    if( fd < 0 ) {
      glogger->error("Failed to create pidfile:'%s', with: '%s'\n", pidfile.c_str(), strerror(errno) );
      delete glogger;
      exit(EXIT_FAILURE);
    }
    char buf[128];
    snprintf(buf,128,"%d",pid);
    write(fd,buf,strlen(buf));
    close(fd);
  }

  Siphon::String mime_types = config.get_core_path("mime_types", "/etc/siphon/mime.types");
  // load mime types
  if( config.mime_types.load(mime_types.c_str()) ) {
    glogger->error("failed to load mime types\n");
    goto shutdown;
  }

  r = runServer(config, options);

shutdown:
  glogger->info("Shutting down\n");

  if( options["daemonize"] == "true" ) {
    // clean up the pid file
    Siphon::String pidfile = config.get_core_path("pidfile","/var/log/siphon/siphon.pid");
    unlink(pidfile.c_str());
  }
  delete glogger;
  return r;
}
