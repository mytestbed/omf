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
/*!\file cmdArray.c
  \brief This file implements an inifinte array which only remembers the 
  last N entries.
*/

#include "o_cmd_array.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <ocomm/o_log.h>
#include <ocomm/o_eventloop.h>

#define CATCHUP_INCR 3 //! Max messages to schedule if node is falling behind

#define ARRAY_LENGTH    200  //! How many coomands to keep
#define MAX_CMD_LENGTH  512  //! Max. CMD length
#define RESEND_INTERVAL  3  //! Interval in sec to check for resend commands

#define HELLO_MESSAGE "NOBODY HELLO"

//! Data-structure, to store object state
typedef struct _cmdInt {

  //! Command 
  char* cmd;
  char cmdBuf[MAX_CMD_LENGTH];

  //! True(1) if scheduled for resend
  int resend;

  //! Command number
  int index;

  //! Counts the number of retry requests
  int resendCnt;

  //! True(1) if message has been sent
  int isSent;

} CmdInt;

//! Data-structure, to store object state
typedef struct _cmdArray {

  //! Name used for debugging
  char* debugName;
  char name[64];

  Socket* out_sock; //! Socket to send out commands

  //! Lowest index with 'resend' flag set. If 0, none is scheduled.
  int startResendCheck;

  TimerEvtSource* resendCheckTimer;

  CmdInt cmds[ARRAY_LENGTH];

  int lastCmd;  //! # of last command stored (0 .. nothing yet)

} CmdArrayInt;


/************************/

static int send_cmd(CmdArrayInt* self, CmdInt* cmd, int resend);
static int send_cmd_str(CmdArrayInt* self, int index, char* cmd, int resend);

static CmdInt* get_cmd(CmdArrayInt* self, int index);

static void service_resends(TimerEvtSource* source, void* handle);

/************************/

CmdArray*
cmd_array_new(
  char* name,   //! Name used for debugging
  Socket* out_sock //! Socket to send out commands
) {
  CmdArrayInt* self = (CmdArrayInt *)malloc(sizeof(CmdArrayInt));
  memset(self, 0, sizeof(CmdArrayInt));

  strcpy(self->name, name);
  self->debugName = self->name;

  self->out_sock = out_sock;

  self->resendCheckTimer = eventloop_every(name, RESEND_INTERVAL, service_resends, self);

  return (CmdArray*)self;
}

/*! Reset the command array. */
void 
cmd_array_reset(
  CmdArray* handle
) {
  CmdArrayInt* self = (CmdArrayInt *)handle;

  self->lastCmd = 0;  //! # of last command stored (0 .. nothing yet)
}

/**
 * Send a command over out_sock. If 'resend' is true
 * mark message as repeat message
 */
int
send_cmd(
  CmdArrayInt* self,
  CmdInt* cmd,
  int resend
) {
  if (send_cmd_str(self, cmd->index, cmd->cmd, resend) != 0) {
    return -1;
  }
  if (resend) {
    cmd->resendCnt++;
  } else {
    cmd->isSent = 1;
  }
  return 0;
}

/**
 * Send a message. If 'resend' is true
 * mark message as repeat message
 */
int
send_cmd_str(
  CmdArrayInt* self,
  int index,
  char* cmd,
  int resend
) {
  char buf[MAX_CMD_LENGTH + 20];
  char* pattern = resend ? "-%d %s\n" : "%d %s\n";
  sprintf(buf, pattern, index, cmd);
  int len = strlen(buf);
  o_log(O_LOG_DEBUG, "sending cmd(%d): <%s>\n", len, buf);
  if (self->out_sock->sendto(self->out_sock, buf, len) != 0) {
    // Re-queue message
    o_log(O_LOG_ERROR, "CmdArray(%s): FIX ME - Message didn't get sent\n",
	  self->name);
    return -1;
  }
  return 0;
}





//! Returns index on success, -1 otherwise
int
cmd_array_send(
  void* handle,	      
  char* cmd   //! Command to add last
) {
  CmdArrayInt* self = (CmdArrayInt *)handle;

  int size = strlen(cmd);
  if (size > MAX_CMD_LENGTH) {
    o_log(O_LOG_ERROR, "CmdArray(%s): Command is too long\n\t'%s'\n", 
	  self->name, cmd);
	// send the error to communicator of node handler via STDOUT
	printf("# ERROR CmdArray: Command is too long: ('%s')\n", cmd);
    return -1;
  }
  if (self->lastCmd >= ARRAY_LENGTH) {
    o_log(O_LOG_ERROR, "CmdArray(%s): Array is full\n", self->name);
    // send the error to communicator of node handler via STDOUT
    printf("CmdArray(%s): Array is full\n", self->name);
    return -1;
  }
  CmdInt* cmdPtr = &self->cmds[self->lastCmd++];
  cmdPtr->cmd = cmdPtr->cmdBuf;
  strcpy(cmdPtr->cmd, cmd);
  cmdPtr->index = self->lastCmd;

  send_cmd(self, cmdPtr, 0);
  return self->lastCmd;
}

/*! Send a command unreliably.
 * Return 0 on success, -1 otherwise
 */
int
cmd_array_unreliable_send(
  void* handle,	      
  char* cmd   //! Command to add last
) {
  CmdArrayInt* self = (CmdArrayInt *)handle;

  return send_cmd_str(self, 0, cmd, 0);
}



CmdInt*
get_cmd(
  CmdArrayInt* self,
  int index //! Command index to return
) {
  if (index > self->lastCmd || index < 0) {
    o_log(O_LOG_ERROR, "CmdArray(%s): Index '%d' out of bounds.\n", 
	  self->name, index);
    return NULL;
  }

  if (index == 0) {
    index = self->lastCmd;
  }
  if (index == 0) {
    return NULL;
  }
  CmdInt* cmdPtr = &self->cmds[index - 1];
  return cmdPtr;
}

char*
cmd_array_get(
  void* handle,	      
  int index //! Command index to return
) {
  CmdArrayInt* self = (CmdArrayInt *)handle;
  CmdInt* cmdPtr = get_cmd(self, index);
  if (cmdPtr == NULL) {
    return NULL;
  }
  char* cmd = cmdPtr->cmd;
  return cmd;
}

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
) {
  CmdArrayInt* self = (CmdArrayInt *)handle;
  CmdInt* cmd = get_cmd(self, index);
  if (cmd == NULL) {
    if (alwaysSend) {
      return send_cmd_str(self, 0, HELLO_MESSAGE, 0);
    }
    return -1;
  }
  o_log(O_LOG_DEBUG2, "CmdArray(%s): Resending '%d'.\n", self->name, index);
  return send_cmd(self, cmd, 1);
}


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
) {
  CmdArrayInt* self = (CmdArrayInt *)handle;

  if (end_index < start_index) {
    o_log(O_LOG_ERROR, "CmdArray(%s): End index %d comes before start index %d.\n", 
	  self->name, end_index, start_index);
    return -1;
  }

  if (end_index > self->lastCmd || start_index <= 0) {
    o_log(O_LOG_ERROR, "CmdArray(%s): Index range '%d-%d' out of bounds.\n", 
	  self->name, start_index, end_index);
    return -1;
  }

  if (self->startResendCheck == 0 || self->startResendCheck > start_index) {
    self->startResendCheck = start_index;
  }

  int i = start_index - 1;
  for (; i < end_index; i++) {
    self->cmds[i].resend = 1;
  }
  return 0;
}

static void
service_resends(
  TimerEvtSource* source,
  void* handle
) {
  CmdArrayInt* self = (CmdArrayInt *)handle;

  o_log(O_LOG_DEBUG2, "CmdArray(%s): Checking for resends.\n", self->name);

  // resendCheck and lstCmd start at 1!
  int i;
  if ((i = self->startResendCheck) == 0) return;

  for (; i <= self->lastCmd; i++) {
    CmdInt* cmd = &self->cmds[i - 1];
    if (cmd->resend) {
      if (send_cmd(self, cmd, 1) == 0) {
	// success
	cmd->resend = 0;
      }
    }
    // Move start of resend index forward if we successfully 
    // have sent everything before that index
    if (!cmd->resend && self->startResendCheck == i) {
      self->startResendCheck++;
    }
  }
  if (self->startResendCheck == self->lastCmd) {
    // All sent
    self->startResendCheck = 0;
  }
}

/*! Process heartbeat from a node
 * Check if that node received all sent message and reschedule 
 * those it may have missed.
 *
 * Returns the number of messages scheduled for re-transmisson.
 */
int
cmd_array_process_heartbeat(
  void* handle, 
  int recvMsg
) {
  CmdArrayInt* self = (CmdArrayInt *)handle;

  if (recvMsg < self->lastCmd) {
    // need to catch up, but in small steps
    int last = recvMsg + CATCHUP_INCR;
    if (last > self->lastCmd) {
      last = self->lastCmd;
    }
    cmd_array_schedule_resend(handle, recvMsg + 1, last);
    return last - recvMsg;
  } else {
    o_log(O_LOG_DEBUG3, "All messages received\n");
    return 0;
  }
}

/*! Return the index of the last reliable command sent.
 */
int
cmd_array_get_last_command_index(
  CmdArray* handle 
) {
  CmdArrayInt* self = (CmdArrayInt *)handle;
  return self->lastCmd;
}
