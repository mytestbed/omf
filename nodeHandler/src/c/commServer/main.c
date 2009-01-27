//
// Copyright (c) 2006-2008 National ICT Australia (NICTA), Australia
//
// Copyright (c) 2004-2008 WINLAB, Rutgers University, USA
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.
//
//
/*!\file main.c
  \brief This file is the starting point.
*/

#include <popt.h>
#include <poll.h>
#include <stdio.h>
#include <strings.h>
#include <string.h>
#include <stdlib.h>
#include <sys/errno.h>
#include <assert.h>

#include <ocomm/o_log.h>
#include <ocomm/o_socket.h>
#include <ocomm/o_socket_group.h>
#include <ocomm/o_eventloop.h>

#include "o_node.h"
#include "o_cmd_array.h"
#include "version.h"

// Network information
#define DEFAULT_MC_IN_ADDR "224.4.0.2"
#define DEFAULT_MC_IN_PORT 9002
#define DEFAULT_IFACE "eth0"

#define DEFAULT_LISTEN_PORT 9004

#define DEFAULT_MC_OUT_ADDR "224.4.0.1"
#define DEFAULT_MC_OUT_PORT 9006

//! Check every so often if all TCP based agents are connected
#define CONN_CHECK_INTERVAL 5 // sec

//! We need to send something every so often to keep the agents bound
#define IDLE_INTERVAL 5 // sec

// max number of char. to buffer from stdin
#define MAX_READ_BUFFER_SIZE 512

//! Pattern to create node name from x/y coordinates
// previous version of NH: #define NODE_NAME_PATTERN "node%d_%d"
#define NODE_NAME_PATTERN "n_%d_%d"

 //************************

static char* mc_in_addr = DEFAULT_MC_IN_ADDR;
static int mc_in_port = DEFAULT_MC_IN_PORT;
static char* iface = DEFAULT_IFACE;

static char* mc_out_addr = DEFAULT_MC_OUT_ADDR;
static int mc_out_port = DEFAULT_MC_OUT_PORT;

static int listen_port = -1;
static int connect_port = -1;

static int connect_agent = 0;

//! Enroll nodes automatically if set
static int automatic_enroll = 0;

//! If true run various API tests
static int run_api_tests = 0;

#define DEFAULT_LOG_FILE "commServer.log"
static int log_level = O_LOG_INFO;
static char* logfile_name = DEFAULT_LOG_FILE;
static FILE* logfile;

static void test_api(Socket* outSock);

// This buffer stores an incomplete command received on stdin from NH 
static char pendingCmdBuff[MAX_READ_BUFFER_SIZE];
static int pendingCmdBuffSize = 0;

//extern int o_log_level;

struct poptOption options[] = {
  POPT_AUTOHELP
  { "mc_in_addr", '\0', POPT_ARG_STRING, &mc_in_addr, 0, 
        "Multicast address to receive on", DEFAULT_MC_IN_ADDR },
  { "mc_in_port", '\0', POPT_ARG_INT, &mc_in_port, 0, 
        "Multicast port to receive on"   },
  { "iface", 'i', POPT_ARG_STRING, &iface, 0, 
        "Interface for MC to bind to "  },

  { "mc_out_addr", '\0', POPT_ARG_STRING, &mc_out_addr, 0, 
        "Multicast address to send on", DEFAULT_MC_OUT_ADDR },
  { "mc_out_port", '\0', POPT_ARG_INT, &mc_out_port, 0, 
        "Multicast port to send on"   },

  { "connect", 'c', POPT_ARG_INT, &connect_port, 0, 
        "Port to actively connect TCP based agents"   },

  { "listen", 'l', POPT_ARG_INT, &listen_port, 0, 
        "Port to listen for TCP based agents"   },

  { "enroll", 'e', POPT_ARG_NONE, &automatic_enroll, 0,
    "Enroll nodes building name from IP address *.*.x.y -> nodex_y"},
 
  { "run-tests", 't', POPT_ARG_NONE, &run_api_tests, 0,
    "Run various API tests"},
 
  { "debug-level", 'd', POPT_ARG_INT, &log_level, 0, 
        "Debug level - error:1 .. debug:4"  },
  { "logfile", '\0', POPT_ARG_STRING, &logfile_name, 0, 
        "File to log to", DEFAULT_LOG_FILE },
  { "version", 'v', 0, 0, 'v', "Print version information and exit" },
  { NULL, 0, 0, NULL, 0 }
};

static int command_count = 0;
static CmdArray* cmdArray;
static TimerEvtSource* connectTimer;
static TimerEvtSource* idleTimer;

//! Socket group to use for TCP connected agents
static Socket* socketGroup = NULL;

static int force_missed_messages = 0;
static int miss_agent_messages = 0;

static void on_idle(TimerEvtSource* source, void* handle);


/********************************************/

/**
 * Handles the WHOAMI command from the agent
 */
static void
enroll_node(
  char* addr, 
  char* msg
) {
  char nameBuf[64];
  char* name = NULL;
  char* groupes = NULL;
  Node* node = NULL;

  // extract name from IP address
  int d1, d2, x, y;
  if (sscanf(addr, "%d.%d.%d.%d", &d1, &d2, &x, &y) != 4) {
    o_log(O_LOG_WARN, "enroll_node: Unknown address pattern '%s'\n", addr);
    return;
  }
  name = nameBuf;
  sprintf(name, NODE_NAME_PATTERN, x, y);
  o_log(O_LOG_DEBUG, "enrolling : %s\n", name);

  // Check if this node has been added to our list of 'known' nodes, i.e. if we
  // previousle received a 'a' command for that node.
  // If the node is unknown and 'automatic_enroll' is set, then enroll this node
  // Otherwise, ignore the enroll request and returns.
  if ((node = node_find(name)) == NULL) {
    if (automatic_enroll) {
      // first time
      o_log(O_LOG_DEBUG, "enrolling : Node %s checked in for first time\n", name);
      node = node_new(name, cmdArray);
    } else {
      o_log(O_LOG_WARN, "enroll_node: Ignore unregistered node '%s'\n", name);
      return;
    }
  }

  int p_major, p_minor;
  char dummy;

  if (sscanf(msg, "%d%c%d", &p_major, &dummy, &p_minor) != 3) { 
    o_log(O_LOG_WARN, "enroll_node: Unknown WHOAMI parameters: '%s'\n", msg);
    return;
  }
  if (p_major != PROTOCOL_MAJOR || p_minor < PROTOCOL_MINOR) {
    o_log(O_LOG_WARN, "enroll_node: Node '%s' speaks unsupported protocol '%d.%d'\n",
	  name, p_major, p_minor);
    return;
  }
  char* p = msg;
  char* laddr;
  char* lport;
  char* a_proto;
  char* image;

  while (*(p++) != ' ');
  laddr = p;
  while (*(++p) != ' '); *(p++) = '\0';
  lport = p;
  while (*(++p) != ' '); *(p++) = '\0';
  a_proto = p;
  while (*(++p) != ' '); *(p++) = '\0';
  image = p;

  assert(node != NULL);
  node_enroll_agent(node, addr);
}

/**
 * Process the heartbeat message from node 'name'.
 *
 * HB sentMsgCnt recvMsgCnt timeStamp delta
 */
void
process_heartbeat(
  char* name, 
  char* msg
) {
  Node* node;
  if ((node = node_find(name)) == NULL) {
    // Got heartbeat message from node we don't know. Ignore!
    o_log(O_LOG_WARN, "Ignore HEARTBEAT from unknown node '%s'\n", name);
    return;
  }
  int sentMsg, recvMsg;
  long timeStamp, delta;
  if (sscanf(msg, "%d %d %d %d", &sentMsg, &recvMsg, &timeStamp, &delta) != 4) {
    o_log(O_LOG_WARN, "HEARTBEAT from node '%s' is in unknown format\n", name);
    o_log(O_LOG_WARN, "\t<%s>\n", msg);
    return;
  }
  // Support testing
  recvMsg -= force_missed_messages;
  force_missed_messages = 0;

  // The current agent reports -1 for no received messages
  if (recvMsg < 0) recvMsg = 0;

  if (node_process_heartbeat(node, sentMsg, recvMsg, timeStamp, delta)) {
    printf("%s ENROLLED\n", name);
  }
}


void
agent_callback(
  SockEvtSource* source,
  void* handle,
  void* buf,
  int buf_size
) {

  if (miss_agent_messages > 0) {
    // drop message
    miss_agent_messages--;
    return;
  }

  char* addr = buf;

  if (addr[buf_size - 1] == '\n')
    addr[--buf_size] = '\0';

  char* p = addr;
  while (*p != '\0' && *(p++) != ' ');
  if (*p == '\0') {
    o_log(O_LOG_WARN, "Expected 'addr seq# cmd opts' but got '%s'\n", addr);
    return;
  }
  *(p - 1) = '\0';
  char* nums = p;
  while (*p != '\0' && *(p++) != ' ');
  if (*p == '\0') {
    o_log(O_LOG_WARN, "Expected 'addr seq# cmd opts' but got '%s %s'\n", addr, nums);
    return;
  }
  *(p - 1) = '\0';
  int num;
  if (sscanf(nums, "%d", &num) != 1) {
    o_log(O_LOG_WARN, "Expected seq# from '%s', but got '%s'\n", addr, nums);
    return;
  }
  char* cmd = p;
  while (*p != '\0' && *(p++) != ' ');
  if (*p == '\0') {
    o_log(O_LOG_WARN, "Expected 'addr seq# cmd opts' but got '%s %s'\n", 
	  addr, nums, cmd);
    return;
  }
  *(p - 1) = '\0';

  char* msg = p;
  o_log(O_LOG_INFO, "msg: <%s><%s><%d><%s>\n", addr, cmd, num, msg);

  if (strcmp(cmd, "WHOAMI") == 0) {
    // Enroll send GROUP message
    enroll_node(addr, msg);
  } else if (strcmp(cmd, "HB") == 0) {
    // Internally process heartbeat
    process_heartbeat(addr, msg);
  } else {
    Node* node;
    if (num != 0 && (node = node_find(addr)) != NULL) {
      // reliable message
      int expect;
      if ((expect = node_next_message(node, num, msg)) != num) {
	// Missed message; ignore for the moment
	o_log(O_LOG_WARN, "Missed message '%d'-'%d' from '%s'\n", expect, num - 1, addr);
	return;
      }
    }
    printf("%s %s %s\n", addr, cmd, msg);
  }
}

static void 
shutdown()

{
  socket_close_all();
  exit(0);
}


//! Called when we successfully connected to a node
static void
on_agent_connect_status (
  SockEvtSource* source, 
  SocketStatus status,
  int err,
  void* handle
){
  Node* node = (Node*)handle;

  switch (status) {
  case SOCKET_WRITEABLE: {
    //char* addr = socket_get_addr(source->socket);
    char* addr = NULL;

    o_log(O_LOG_DEBUG, "agentMonitor: Socket '%s' connected\n", source->name);
    node_set_connected(node, 1);
    
    // Add the established socket to the socket group 
    // associated with the cmd array. 
    socket_group_add(socketGroup, source->socket);
    node_enroll_agent(node, NULL);
    eventloop_on_read_in_channel(source->socket, agent_callback, 
				 on_agent_connect_status, handle);  
    eventloop_socket_remove(source);
    break;
  }

  case SOCKET_CONN_REFUSED:
    o_log(O_LOG_WARN, "agentMonitor: Node '%s' refused connection\n", node->name);
    node_set_connected(node, 0);
    eventloop_socket_remove(source);
    socket_group_remove(socketGroup, source->socket);
    break;

  case SOCKET_CONN_CLOSED:
    o_log(O_LOG_WARN, "agentMonitor: Node '%s' closed connection\n", node->name);
    node_reset(node);
    socket_group_remove(socketGroup, source->socket);
    eventloop_socket_remove(source);
    printf("%s LOST_AGENT\n", node->name);
    break;

  default:
    if (err == 0) {
      o_log(O_LOG_DEBUG, "agentMonitor: Status '%d' for socket '%s'\n", 
	    status, source->socket->name);
    } else {
      o_log(O_LOG_DEBUG, "agentMonitor: Status '%d-%d' for socket '%s': %s\n", 
	    status, err, source->socket->name, strerror(err));
    }

  }
}

/* Initiate connection to node's agent.
 */
static void
connect_to_agent(
  char* ip_addr, 
  Node* node
) {
  o_log(O_LOG_DEBUG, "connectToAgent: Connectiong to '%s'\n", ip_addr);

  Socket* sock = socket_tcp_out_new(node->name, ip_addr, connect_port);
  node_set_socket(node, sock);

  /*
  eventloop_on_read_in_channel(sock, agent_callback, 
			       on_agent_connect_status, node);  
  */
  eventloop_on_out_channel(sock, on_agent_connect_status, node);  

}


static void
process_cmd(
  char* buf,
  int len,
  Socket* out_sock
) {
  char cmd = *buf;
  char out_buf[512];
  int out_len = 512;

  buf++; len--;
  while (len > 0 && (*buf == ' ' || *buf == '\t')) {
    buf++; len--;
  }
  o_log(O_LOG_DEBUG, "cmd(%c): <%s>\n", cmd, buf);

  switch(cmd) {
  case 'h':
    printf("  a <ip name [{group}]>.. Add a node mapping from IP address to name and opt groupes\n");
    printf("  A <node_name group>  .. Add an additional group to a node\n");
    printf("  d <log_level>     .. Set log level\n");
    printf("  e [count=1]       .. Make next node to report <count> less messages received.\n");
    printf("  E [count=1]       .. Drop <count> messages from agents.\n");
    printf("  f <fileName>      .. Read further commands from file\n");
    printf("  p [node_name]     .. Print state of node. If name missing print all\n");
    printf("  q                 .. Quit program\n");
    printf("  r [index]         .. Resend command, if no argument, send last\n");
    printf("  R                 .. Send RESET command and also reset internal state\n");
    printf("  s <msg>           .. Send unreliable message\n");
    printf("  S <msg>           .. Send reliable message\n");
    printf("  X <node_name>     .. Remove all groups for the node <node_name>\n");
    return;

  case 'a': {
    char* p = buf;
    while (*p == ' ') p++; // skip leading spaces
    char* ip = p;
    while (*(++p) != ' ');
    *(p++) = '\0';
    while (*p == ' ') p++;
    char* name = p;
    while (!(*p == ' ' || *p == '\0')) p++;
    int hasGroup = *p == ' ';
    *(p++) = '\0';
    o_log(O_LOG_DEBUG2, "cmd:a: name: <%s> ip: <%s>\n", name, ip);
    Node* node = node_new_with_ip(name, ip, cmdArray);
    while (hasGroup) {
      while (*p == ' ') p++; // skip leading spaces
      if (*p != '\0') {
	char* group = p;
	while (!(*p == ' ' || *p == '\0')) p++;
	hasGroup = *p == ' ';
	*(p++) = '\0';
	node_add_group(node, group);
      } else {
	hasGroup = 0;
      }
    }

    if (connect_agent) {
      connect_to_agent(ip, node);
    }
    return;
  }

  case 'A': {
    // TODO: Handle missing arguments
    char* p = buf;
    while (*p == ' ') p++; // skip leading spaces
    char* name = buf;
    while (*(++p) != ' ');
    *(p++) = '\0';
    while (*p == ' ') p++; // skip leading spaces
    char* group = p;

    Node* n = node_find(name);
    if (n == NULL) {
      printf("ERROR: Unknown node '%s'\n", name);
      return;
    }
    node_add_group(n, group);
    return;
  }

  case 'd': {
    if (sscanf(buf, "%d", &log_level) != 1) {
      printf("ERROR: Expected int, but got '%s'\n", buf);
      return;
    }
    o_set_log_level(log_level);
    return;
  }

  case 'e': {
    force_missed_messages = 1;
    if (len > 0) {
      if (sscanf(buf, "%d", &force_missed_messages) != 1) {
	printf("Expected number, but got '%s'\n", buf);
	return;
      } 
    }
    return;
  }

  case 'E': {
    miss_agent_messages = 1;
    if (len > 0) {
      if (sscanf(buf, "%d", &miss_agent_messages) != 1) {
	printf("Expected number, but got '%s'\n", buf);
      } 
    }
    return;
  }

  case 'f': {
    FILE* f = fopen(buf, "r");
    if (f == NULL) {
      o_log(O_LOG_ERROR, "Can't open file '%s'\n\t%s\n",
	    buf, strerror(errno));
      return;
    }
    while (fgets(out_buf, out_len, f) != NULL) {
      int len = strlen(out_buf) - 1;
      if (len > 1) {
	out_buf[len] = '\0';
	o_log(O_LOG_DEBUG, "%s(%d): <%s>\n", buf, len, out_buf);
	process_cmd(out_buf, len, out_sock);
      }
    }
    return;
  }

  case 'p': {
    if (len > 0) {
      Node* n = node_find(buf);
      if (n != NULL) {
	node_print_state(n);
      } else {
	printf("Unknown node '%s'\n", buf);
      }
    } else {
      node_all_print_state();
    }
    return;
  }

  case 'q':
    shutdown();
    return;

  case 'r': {
    int index = 0;

    if (len > 0) {
      sscanf(buf, "%d", &index);
    }
    cmd_array_resend(cmdArray, index, 0);
    return;
  }

  case 'R':
    cmd_array_unreliable_send(cmdArray, "* RESET");
    node_init(400);
    cmd_array_reset(cmdArray);
    return;

  case 's':
    cmd_array_unreliable_send(cmdArray, buf);
    return;

  case 'S':
    if (cmd_array_send(cmdArray, buf) == -1) {
    	o_log(O_LOG_ERROR, "ERROR Processing cmd '%c': <%s>.\n", cmd, buf);
    }
    return;

  // Remove all the groups for a node
  // (e.g. when a node is removed from all topologies)
  case 'X': {
    if (len > 0) {
      Node* n = node_find(buf);
      if (n == NULL) {
        printf("ERROR: Unknown node '%s'\n", buf);
        return;
      }
      node_remove_group(n);
    } else {
      printf("ERROR: Missing node name for command 'X'\n");
    }
    return;
  }
  
  case '#': // ignore line
    return;

  default:
    o_log(O_LOG_ERROR, "Unknown command '%c'. Type 'h' for list.\n", cmd);
    return;
  }
  out_len = strlen(out_buf);
  o_log(O_LOG_DEBUG, "sending cmd(%d): <%s>\n", out_len, out_buf);
  socket_sendto(out_sock, out_buf, out_len);
}

void
stdin_callback(
  SockEvtSource* source,
  void* handle,
  void* buf,
  int buf_size
) {
  char* cmdBuf = (char*)buf;
  Socket* outSock = (Socket*)handle;

  o_log(O_LOG_DEBUG, "(main.c) stdin: (%s)\n", cmdBuf);
  int cmdIndex = 0;
  char* tmpBuf;

  
  // We have to handle the cases where two (or more) commands are received back-to-back on stdin
  // Each command ends with '\n', and the entire stdin ends with '\0'
  for (tmpBuf = cmdBuf; *tmpBuf != '\0'; tmpBuf++) {
  	// Loop on all the character from stdin...
  	cmdIndex++;
  	if (*tmpBuf == '\n') {
  		// Found '\n' -> execute the related command...
  		*tmpBuf = '\0';
  		// Check if we have a pending command from the last previous call of this method
		// (a pending command is an incomplete command, i.e. a command that has been
		// cut in two halves due to the OS flushing the STDIN buffer while the NH is
		// still writing a command into it for the commServer)
  		if (pendingCmdBuffSize != 0) {
  			//o_log(O_LOG_DEBUG, "(main.c) TDEBUG - Got a pending command \n");
			strncat(pendingCmdBuff, cmdBuf, cmdIndex);
  			o_log(O_LOG_DEBUG, "(main.c) - full pending cmd: (%s) \n", pendingCmdBuff);
  			process_cmd(pendingCmdBuff, strlen(pendingCmdBuff), outSock);
			pendingCmdBuffSize = 0;
  		}
		else {
  			process_cmd(cmdBuf, cmdIndex, outSock);
		}
		// Move on...
  		cmdBuf = tmpBuf+1;
  		cmdIndex = 0;
  	}
  }
  // Check if there is an incomplete/pending command left in the buffer from STDIN
  // If so, store. Next time this method is called, we will complete this stored command with its 
  // remaining part from STDIN 
  if (tmpBuf != cmdBuf) {
  	//o_log(O_LOG_DEBUG, "(main.c) TDEBUG - Got an incomplete command\n");
  	strncpy(pendingCmdBuff,cmdBuf,cmdIndex+1); // '+1' to copy the final '\0' at the end of the cmdBuf
	pendingCmdBuffSize = cmdIndex;
	o_log(O_LOG_DEBUG, "(main.c) - Storing incomplete cmd: (%s) (%d)\n",pendingCmdBuff,pendingCmdBuffSize);
  }
}

void
status_callback(
 SockEvtSource* source,
 SocketStatus status,
 int errno,
 void* handle
) {
  switch (status) {
  case SOCKET_CONN_CLOSED: {
    Socket* outSock = (Socket*)handle;
    
    o_log(O_LOG_DEBUG, "socket '%s' closed\n", source->name);
    socket_group_remove(outSock, source->socket);
    break;
  }
  }
}


//! Called when a node connects via TCP
void
on_connect(
  Socket* newSock, 
  void* handle
) {
  Socket* outSock = (Socket*)handle;

  o_log(O_LOG_DEBUG, "New node connected\n");
  socket_group_add(outSock, newSock);
  eventloop_on_read_in_channel(newSock, agent_callback, status_callback, outSock); 	
}



//! Check if all TCP agent are connected
static void
on_connectT(
  TimerEvtSource* source,
  void* handle
) {
  //o_log(O_LOG_DEBUG, "ConnectT: Check if all nodes are connected\n");

  Node* node = node_first();
  while (node != NULL) {
    //o_log(O_LOG_DEBUG3, "ConnectT: Checking node '%s'\n", node->name);
    if (!node_is_connected(node)) {
      //o_log(O_LOG_DEBUG, "ConnectT: Trying to connect to '%s' again.\n", node->name);
      Socket* s = node_get_socket(node);
      socket_reconnect(s);
      eventloop_on_out_channel(s, on_agent_connect_status, node);  
    }
    node = node_next(node);
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

  while ((c = poptGetNextOpt(optCon)) >= 0) {
    switch (c) {
    case 'v':
      printf(V_STRING, VERSION);
      printf(COPYRIGHT);
      return 0;
    }
  }
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

  o_log(O_LOG_INFO, V_STRING, VERSION);
  o_log(O_LOG_INFO, COPYRIGHT);

  o_log(O_LOG_DEBUG, "Enroll: %d\n", automatic_enroll);

  eventloop_init(100);
  node_init(400);

  Socket* outSock = NULL;

  // commServer in TCP client mode - it connects to the node agents
  if (connect_port >= 0) {
    socketGroup = outSock = socket_group_new("sg_out");
    connectTimer = eventloop_every("connectT", CONN_CHECK_INTERVAL, 
				   on_connectT, NULL);
    connect_agent = 1;
  // commServer in TCP server mode - it listen for connections from node agents
  // -- not fully tested --
  } else if (listen_port >= 0) {
    socketGroup = outSock = socket_group_new("sg_out");
    Socket* serverSock = socket_server_new("server", listen_port, 
					   on_connect, outSock);
  // commServer in TCP multicast mode 
  } else {
    Socket* inSock = socket_mc_in_new("in", mc_in_addr, mc_in_port, iface);
    eventloop_on_read_in_channel(inSock, agent_callback, NULL, NULL);

    outSock = socket_mc_out_new("out", mc_out_addr, mc_out_port, iface);
    //eventloop_on_in_channel(inSock, agent_callback, NULL, NULL);

    //! Timer to ensure that something gets sent
    idleTimer = eventloop_every("idleT", IDLE_INTERVAL, on_idle, NULL);
  }

  eventloop_on_stdin(stdin_callback, outSock);
  cmdArray = cmd_array_new("global", outSock);

  if (run_api_tests) {
    test_api(outSock);
  }


  eventloop_run();
  return(0);
}

//! Send something every few seconds
static void
on_idle(
  TimerEvtSource* source,
  void* handle
) {
  cmd_array_resend(cmdArray, 0, 1);
}

  
//! Test various API calls
void
test_api(
  Socket* outSock
) {
  TimerEvtSource* t1 = eventloop_every("tick", 3, NULL, NULL);

  Node* n1 = node_new("node_1", cmdArray);
  Node* n2 = node_find("node_1");

  cmd_array_send(cmdArray, "Foo fighters");
  cmd_array_send(cmdArray, "Second Foo fighters");
  cmd_array_send(cmdArray, "Third Foo fighters");
  cmd_array_unreliable_send(cmdArray, "Unreliable Foo fighters");

  char* s1 = cmd_array_get(cmdArray, 1);
  char* s2 = cmd_array_get(cmdArray, 2);
  cmd_array_get(cmdArray, 4);
}
