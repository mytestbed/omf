/*!\file client.c
  \brief Simple client connecting to TCP server and send messages
*/

#include <popt.h>
#include <stdio.h>
#include <strings.h>
#include <string.h>
#include <stdlib.h>
#include <sys/errno.h>
#include <assert.h>

#include "ocomm/o_log.h"
#include "ocomm/o_socket.h"

 //************************
static int port;
static char* addr;

#define DEFAULT_LOG_FILE "client.log"
static int log_level = O_LOG_INFO;
static char* logfile_name = DEFAULT_LOG_FILE;
static FILE* logfile;


struct poptOption options[] = {
  POPT_AUTOHELP
  { "addr", 'a', POPT_ARG_STRING, &addr, 0, 
        "Address to connect to"},
  { "port", 'p', POPT_ARG_INT, &port, 0, 
        "Port to receive on"},

  { "debug-level", 'd', POPT_ARG_INT, &log_level, 0, 
        "Debug level - error:1 .. debug:4"  },
  { "logfile", 'l', POPT_ARG_STRING, &logfile_name, 0, 
        "File to log to", DEFAULT_LOG_FILE },
  { NULL, 0, 0, NULL, 0 }
};


/********************************************/


void
server_callback(
  Socket* source,
  void* handle,
  void* buf,
  int buf_size
) {

  char* addr = buf;
  o_log(O_LOG_INFO, "reply: <%s>\n", addr);
  printf("reply: %s\n", addr);
}

static void 
shutdown()

{
  socket_close_all();
  exit(0);
}

void
stdin_callback(
  Socket* source,
  void* handle,
  void* b,
  int len
) {
  char* buf = (char*)b;
  char cmd = *buf;
  Socket* outSock = (Socket*)handle;

  o_log(O_LOG_DEBUG, "stdin: <%s>\n", b);

  buf++; len--;
  while (len > 0 && (*buf == ' ' || *buf == '\t')) {
    buf++; len--;
  }
  o_log(O_LOG_DEBUG, "cmd(%c): <%s>\n", cmd, buf);

  switch(cmd) {
  case 'h':
    printf("  m <msg>           .. Send message\n");
    printf("  q                 .. Quit program\n");
    return;

  case 'q':
    shutdown();
    return;

  case 'm':
    o_log(O_LOG_DEBUG, "sending cmd(%d): <%s>\n", len, buf);
    socket_sendto(outSock, buf, len);
    return;

  default:
    o_log(O_LOG_ERROR, "Unknown command '%c'. Type 'h' for list.\n", cmd);
    return;
  }
}

int
main(
  int argc,
  const char *argv[]
) {
  char c;

  poptContext optCon = poptGetContext(NULL, argc, argv, options, 0);
  poptSetOtherOptionHelp(optCon, "configFile");
  poptGetNextOpt(optCon);

  o_set_log_file(logfile_name);
  o_set_log_level(log_level);
  setlinebuf(stdout);

  if (c < -1) {	
    /* an error occurred during option processing */
    fprintf(stderr, "%s: %s\n",
	    poptBadOption(optCon, POPT_BADOPTION_NOALIAS),
	    poptStrerror(c));
    return -1;
  }

  eventloop_init(10);

  Socket* sock = socket_tcp_out_new("out", addr, port);
  eventloop_on_read_in_channel(sock, server_callback, NULL);  
  
  eventloop_on_stdin(stdin_callback, sock);
  eventloop_run();
  return(0);
}
