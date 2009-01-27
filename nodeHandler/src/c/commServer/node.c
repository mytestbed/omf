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
/*!\file node.c
  \brief This file implements a node object representing the connecting 
node agent. 
*/

#include "o_node.h"

#define _GNU_SOURCE
#include <search.h>
#include <sys/errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <ocomm/o_log.h>
#include <ocomm/o_eventloop.h>
#include <ocomm/o_socket.h>

#define MAX_NAME_LENGTH 32

//! Data-structure holding node a node group.
typedef struct _nodeGroup {

  char group[MAX_NAME_LENGTH + 1];

  struct _nodeGroup* next;
} NodeGroup;


//! Data-structure holding node state.
typedef struct _nodeInt {
  //! Name used for debugging
  char* debugName;

  //! Initial name of node
  char name[MAX_NAME_LENGTH + 1];

  //! True if connected, false otherwise
  int is_connected;

  //! Ptr to list of groupes
  NodeGroup* firstGroup;

  //! Number of received reliable commands
  int receivedCmds;

  //! Counts how many times a node tried to enroll
  int enrollCnt;

  //! Counts number of retransmission caused by this node
  int resendCnt;

  //! Contains last received timestamp
  time_t timeStamp;

  //! Stores longest message 'draught' experienced by agent
  int longestDelta;

  //! Timestamp when checked in
  time_t checkedInAt;

  //! Conduit for sending commands to node
  CmdArray* cmdArray;

  //! Hold associated socket
  Socket* socket;

  ENTRY n_entry;  //! Supporting hsearch 

  char ip_name[32];
  ENTRY i_entry;  //! Supporting hsearch 

  //! Pointer to next instance
  struct _nodeInt* next;
} NodeInt;

static int store(NodeInt* self, char* name);

static struct hsearch_data name2node;
static NodeInt* instances = NULL;

/*! Initialize node environment. Call once at the beginning.
 */ 
int
node_init(
  int max_nodes //! Max. number of nodes expected
) {
  if (instances != NULL) {
    // TODO: Reclaim all existing node structures
  }
  instances = NULL;
  memset(&name2node, 0, sizeof(struct hsearch_data));
  if (hcreate_r(3 * max_nodes, &name2node) != 1) {
    o_log(O_LOG_ERROR, "Node: Initialization of hash table failed\n\t%s\n", 
	  strerror(errno));
    return -1;
  }
  return 0;
}

Node*
node_find(
  char* name   //! Name used for debugging
) {
  ENTRY search;
  int res;
  ENTRY* rep;

  search.key = name;
  search.data = NULL;
  res = hsearch_r(search, FIND, &rep, &name2node);
  if (res == 0) {
    return NULL;
  }
  Node* n = (Node*)rep->data;
  return n;
}

Node*
node_first()

{
  return (Node*)instances;
}


/*! Return the next node of the list of existing nodes
 */
Node*
node_next(
  Node* curr
) {
  NodeInt* self = (NodeInt *)curr;
  return (Node*)(self != NULL ? (Node*)self->next : NULL);
}



Node*
node_new(
  char* name,   //! Name used for debugging
  CmdArray* cmdArray  //! Conduit for sending commands to node
) {
  NodeInt* self = (NodeInt *)malloc(sizeof(NodeInt));
  memset(self, 0, sizeof(NodeInt));

  strcpy(self->name, name);
  self->debugName = self->name;
  self->cmdArray = cmdArray;
  self->n_entry.key = self->name;
  self->n_entry.data = self;
  self->timeStamp = -1;
  self->checkedInAt = -1;

  if (store(self, self->name) < 0) return NULL;
  self->next = instances;
  instances = self;

  return (Node*)self;
}

Node*
node_new_with_ip(
  char* name,   //! Name of node 
  char* ipAddr, //! IP address in form '10.1.1.1'
  CmdArray* cmdArray  //! Conduit for sending commands to node
) {
  NodeInt* self = (NodeInt *)node_new(name, cmdArray);
  if (self == NULL) return NULL;

  strcpy(self->ip_name, ipAddr);
  if (store(self, self->ip_name) < 0) return NULL;

  return (Node*)self;
}


static int 
store(
  NodeInt* self,
  char* name
) {
  int res;
  ENTRY* rep;

  self->n_entry.key = name;
  self->n_entry.data = self;
  res = hsearch_r(self->n_entry, ENTER, &rep, &name2node);
  if (res == 0) {
    o_log(O_LOG_ERROR, 
	  "Node(%s): Can't store node in hashtable. Make table bigger: %s\n", 
	  name, strerror(errno));
    return -1;
  } 
  return 0;
}

static void
get_youare_message(
  NodeInt* self,
  char* addr,  //! Currently known address of node
  char* cmd //! buffer to write message into
) {
  int lastCmd = cmd_array_get_last_command_index(self->cmdArray);
  char* target = (addr != NULL) ? addr : self->ip_name;
    
  sprintf(cmd, "%s YOUARE %s %d ", target, self->name, lastCmd);
}

int
node_enroll_agent(
  Node* handle,		   
  char* addr  //! Currently known address of node
) {
  NodeInt* self = (NodeInt *)handle;
  
  if (self->enrollCnt++ > 0) {
    o_log(O_LOG_WARN, "Node(%s): Re-enrolling - %d\n", 
	  self->name, self->enrollCnt);
    self->receivedCmds = 0;
  }

  char cmd[1024];
  get_youare_message(self, addr, cmd);
  //  int lastCmd = cmd_array_get_last_command_index(self->cmdArray);
  //  sprintf(cmd, "%s YOUARE %s %d ", addr, self->name, lastCmd);

  char* p = cmd;
  NodeGroup* n = self->firstGroup;
  while (n != NULL) {
    while (*(++p) != '\0');
    *(p++) = ' ';
    strcpy(p, n->group);
    n = n->next;
  }
  cmd_array_unreliable_send(self->cmdArray, cmd);
}


//! Print internal state of node to STDOUT
int
node_print_state(
  Node* handle	
) {
  NodeInt* self = (NodeInt *)handle;

  printf("Node %s: received: %d enrolls: %d  resends: %d  checkedIn: %d lastSeen: %d draught: %d\n",
	 self->name, 
	 self->receivedCmds,
	 self->enrollCnt, self->resendCnt, 
	 self->checkedInAt,
	 eventloop_now() - self->timeStamp,
	 self->longestDelta);
}

/*! Constructs and returns the command line to make a call to the 
 * ALIAS function of a remote node Agent */
static void
get_alias_message(
  NodeInt* self,
  char* name,  //! Additional group for node
  char* cmd //! buffer to write message into
) {
  int lastCmd = cmd_array_get_last_command_index(self->cmdArray);
  char* addr = self->ip_name;
    
  sprintf(cmd, "%s ALIAS %s %d ", addr, name, lastCmd);
}

/**
 * Remove all the groups for a given node
 * For example, this is necessary when a node is removed from all 
 * the existing topologies.
 */
void
node_remove_group(
  Node* handle
) {
  NodeInt* self = (NodeInt *)handle;
  self->firstGroup = NULL;
  o_log(O_LOG_DEBUG, "Node(%s): All group removed\n", self->name);
  // TODO: Release the memory used by the list of groups?
}

/*! Add an group to the node. Only transmitted at enroll */
void
node_add_group(
  Node* handle,
  char* name  //! Additional group for node
) {
  NodeInt* self = (NodeInt *)handle;
  NodeGroup* a = (NodeGroup *)malloc(sizeof(NodeGroup));
  memset(a, 0, sizeof(NodeGroup));

  strcpy(a->group, name);
  a->next = self->firstGroup;
  self->firstGroup = a;
  
  // If this remote node is already in the connected state, 
  // then we should also send an "ALIAS" command to it
  if (self->is_connected) {
    char cmd[1024];
    get_alias_message(self, name, cmd);
    cmd_array_unreliable_send(self->cmdArray, cmd);
  }
}

//! Print internal state of ALL nodes to STDOUT
int
node_all_print_state()

{
  NodeInt* n = instances;

  int i = 0;
  while (n != NULL) {
    node_print_state((Node*)n);
    n = n->next;
    i++;
  }
  printf("%d nodes enrolled\n", i); 
}

/*
 * Send a command to node to resend msgId.
 */
static void
send_retry(
  NodeInt* self,
  int first,
  int last
) {
  char cmd[64];
  sprintf(cmd, "%s RETRY %d %d", self->name, first, last);
  o_log(O_LOG_DEBUG2, "Node(%s): Request retry of msgs '%d-%d'\n", self->name, first, last);
  cmd_array_unreliable_send(self->cmdArray, cmd);
}

/*! Process heartbeat from node
 * Check if we received all messages from this node and
 * request resending of those we have missed.
 *
 * Returns 1 if this is the first heartbeat, otherwise 0
 */
int
node_process_heartbeat(
  Node* handle,
  int sentMsg, // Number of messages node has sent
  int recvMsg, // Number of messages node has received
  int timeStamp, // Timestamp of heartbeat
  int delta // Time since last packet received
) {
  NodeInt* self = (NodeInt *)handle;
  int first = 0;

  self->resendCnt += cmd_array_process_heartbeat(self->cmdArray, recvMsg);
  //self->timeStamp = timeStamp;
  self->timeStamp = eventloop_now();
  if (self->checkedInAt < 0) {
    self->checkedInAt = eventloop_now();
    first = 1;
  }

  //TODO: Implement checking if we received all node messages
  int expect = self->receivedCmds;
  if (expect <  sentMsg) {
    // Missed message
    send_retry(self, expect + 1, sentMsg);
    o_log(O_LOG_INFO, "Missed message(s) '%d'-'%d' from '%s'\n", 
	  expect + 1, sentMsg, self->name);
  }

  if (delta > self->longestDelta) {
    self->longestDelta = delta;
  }
  
  return first;
}

/**
 * Return the next expected seq no. The provided 'seqNo'
 * and 'message' are the currently received ones. 
 */
int
node_next_message(
  Node* handle,
  int seqNo,
  char* message
) {
  NodeInt* self = (NodeInt *)handle;
  int expected = self->receivedCmds + 1;

  if (expected == seqNo) {
    self->receivedCmds = expected;
  } else if (expected < seqNo) {
    // TODO: We should store this message and not request it again
    send_retry(self, expected, seqNo);
  }
  return expected;
}

/**
 * Set the 'connected' state according to flag.
 */
void
node_set_connected(
  Node* node,
  int flag
) {
  NodeInt* self = (NodeInt *)node;
  self->is_connected = flag;
}


/**
 * Return true if the node is connected, false otherwise.
 */
int
node_is_connected(
  Node* node
) {
  NodeInt* self = (NodeInt *)node;
  return self->is_connected;
}


/**
 * Associate a socket with this node.
 */
void
node_set_socket(
  Node* node,
  Socket* socket
) {
  NodeInt* self = (NodeInt *)node;
  self->socket = socket;
}

/**
 * Return the associated socket.
 */
Socket*
node_get_socket(
  Node* node
) {
  NodeInt* self = (NodeInt *)node;
  return self->socket;
}

void
node_reset(
  Node* node
) {
  NodeInt* self = (NodeInt *)node;

  self->is_connected = 0;
  self->receivedCmds = 0;
  self->enrollCnt = 0;
  o_log(O_LOG_DEBUG, "Node(%s): enroll count - %d\n", 
	self->name, self->enrollCnt);
  self->resendCnt = 0;
  self->timeStamp = -1;
  self->checkedInAt = -1;
  self->longestDelta = 0;
}


