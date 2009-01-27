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
/*! \file o_node.h
  \brief Header file for node object
  \author Max Ott (max@winlab.rutgers.edu)
 */


#ifndef O_NODE_H
#define O_NODE_H


//! Data-structure holding node state.
typedef struct _node {

  //! Initial name of node
  char* name;

} Node;

#include "o_cmd_array.h"

/*! Initialize node environment. Call once at the beginning.
 */ 
int
node_init(
  int max_nodes //! Max. number of nodes expected
);

/*! Find and return a named node.
 */
Node*
node_find(
  char* name   //! Name of node to look for
);

/*! Return the first node of the list of existing nodes
 */
Node*
node_first();

/*! Return the next node of the list of existing nodes
 */
Node*
node_next(
  Node* curr
);

/*! Create a new node
 */
Node*
node_new(
  char* name,   //! Initial name of node
  CmdArray* cmdArray  //! Conduit for sending commands to node
);

/*! Create a new node. 
 * Also provide the IP address of the node. This allows the 
 * node to be looked up with 'node_find_by_ip'
 */
Node*
node_new_with_ip(
  char* name,   //! Name of node 
  char* ipAddr, //! IP address in form '10.1.1.1'
  CmdArray* cmdArray  //! Conduit for sending commands to node
);

/*!
 * Remove all the groups for a given node
 * For example, this is necessary when a node is removed from all 
 * the existing topologies.
 */
void
node_remove_group(
  Node* handle
);

/*! Add an group to the node. Only transmitted at enroll */
void
node_add_group(
  Node* handle,
  char* addr  //! Additional group for node
);

/* int */
/* node_send_group_to( */
/*   Node* handle, */
/*   char* addr  //! Currently known address of node */
/* ); */

int
node_enroll_agent(
  Node* handle,		   
  char* addr  //! Currently known address of node
);

//! Print internal state of node to STDOUT
int
node_print_state(
  Node* handle	
);

//! Print internal state of ALL nodes to STDOUT
int
node_all_print_state();

/*! Process heartbeat from node
 * Check if we received all messages from this node and
 * request resending of those we have missed.
 * Returns 1 if this is the first heartbeat, otherwise 0
 */
int
node_process_heartbeat(
  Node* node,
  int sentMsg, // Number of messages node has sent
  int recvMsg, // Number of messages node has received
  int timeStamp, // Timestamp of heartbeat
  int delta // Time since last packet received
); 

/**
 * Return the next expected seq no. The provided 'seqNo'
 * and 'message' are the currently received ones. 
 */
int
node_next_message(
  Node* node,
  int seqNo,
  char* message
);

/**
 * Set the 'connected' state according to flag.
 */
void
node_set_connected(
  Node* node,
  int flag
);

/**
 * Return true if the node is connected, false otherwise.
 */
int
node_is_connected(
  Node* node
);

/**
 * Associate a socket with this node.
 */
void
node_set_socket(
  Node* node,
  Socket* socket
);

/**
 * Return the associated socket.
 */
Socket*
node_get_socket(
  Node* node
);

/*
 * Reset the node's internal state. Should be
 * done if the node is declared to be lost.
 */
void
node_reset(
  Node* node
);

#endif
