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
/*! \file o_cmd_array.h
  \brief Header file for cmd_array object
  \author Max Ott (max@winlab.rutgers.edu)
 */


#ifndef O_CMD_ARRAY_H
#define O_CMD_ARRAY_H

#include "ocomm/o_socket.h"


//! Data-structure holding cmd_array state.
typedef struct _cmd_array {

  //! Name used for debugging
  char* name;

} CmdArray;



/*! Create a new cmd_array
 */
CmdArray*
cmd_array_new(
  char* name,   //! Name used for debugging
  Socket* out_sock //! Socket to send out commands
);

/*! Reset the command array. */
void 
cmd_array_reset(
  CmdArray* handle
);

/*! Send a command reliably.
 * Return the index on success, -1 otherwise
 */
int
cmd_array_send(
  void* handle,	      
  char* cmd   //! Command to add last
);

/*! Send a command unreliably.
 * Return 0 on success, -1 otherwise
 */
int
cmd_array_unreliable_send(
  void* handle,	      
  char* cmd   //! Command to add last
);

/*! Return the command at index 
 */
char*
cmd_array_get(
  void* handle,	      
  int index //! Command index to return
);

/*! Resend command at index. 
 * 
 * If index is 0, resend last command sent.
 * If no command with this index is available, but 'alwaysSend'
 * is true, send HELLO_MESSAGE.
 *
 * Return 0 on success, -1 otherwise
 */
int
cmd_array_resend(
  void* handle,	      
  int index, //! Command index to resend
  int alwaysSend
);

/*! Resend range of commands at next opportunity.
 * Schedule the commands in range 'start_index' to inclusive
 * 'end_index' for resending. 
 *
 * Note, the commands may not have been sent when this method
 * returns.
 *
 * Return 0 on success, -1 otherwise (primarily when out of range
 */
int
cmd_array_schedule_resend(
  void* handle,	      
  int start_index, //! Start of range
  int end_index //! Inclusive end of range
);

/*! Process heartbeat from a node
 * Check if that node received all sent message and reschedule 
 * those it may have missed to be delivered through 'nodeSocket'.
 *
 * Returns the number of messages scheduled for re-transmisson.
 */
int
cmd_array_process_heartbeat(
  void* handle, 
  int recvMsg
);

/*! Return the index of the last reliable command sent.
 */
int
cmd_array_get_last_command_index(
  CmdArray* handle 
);


#endif
