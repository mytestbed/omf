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
/*!\file socket.c
  \brief This file contains a thin layer over sockets.
*/

#include "ocomm/o_socket.h"
#include "ocomm/o_socket_group.h"
#include "ocomm/o_log.h"

#include <string.h>

static o_socket_sendto sendto;
static o_get_sockfd get_sockfd;

typedef struct _sockHolder {

  Socket* socket;
  struct _sockHolder* next;

} SocketHolder;


//! Data-structure, to store object state
typedef struct _socketGroup {

  //! Name used for debugging
  char* name;

  o_socket_sendto sendto;
  o_get_sockfd get_sockfd;


  SocketHolder* first;

  //! Local memory for debug name
  char nameBuf[64];

} SocketGroupInt;




void
socket_group_add(
  Socket* this,   //! This object
  Socket* socket  //! Socket to add
) {
  SocketGroupInt* self = (SocketGroupInt*)this;

  SocketHolder* holder = (SocketHolder *)malloc(sizeof(SocketHolder));
  memset(holder, 0, sizeof(SocketHolder));

  holder->socket = socket;
  holder->next = self->first;
  self->first = holder;
}

void
socket_group_remove(
  Socket* this,   //! This object
  Socket* socket  //! Socket to remove
) {
  SocketGroupInt* self = (SocketGroupInt*)this;

  SocketHolder* prev = NULL;
  SocketHolder* holder = self->first;
  while (holder != NULL) {
    if (socket ==  holder->socket) {
      // remove holder
      if (prev == NULL) {
	self->first = holder->next;
      } else {
	prev->next = holder->next;
      }
      free(holder);
      return;
    }
    prev = holder;
    holder = holder->next;
  }
}

static int
sg_sendto(
  Socket* this,
  char* buf,
  int buf_size
) {
  SocketGroupInt* self = (SocketGroupInt*)this;
  int result = 0;

  SocketHolder* holder = self->first;
  while (holder != NULL) {
    Socket* s = holder->socket;
    int r;

    if ((r = s->sendto(s, buf, buf_size)) < result) {
      result = r;
    }
    holder = holder->next;
  }
  return result;
}

static int
sg_get_sockfd(
  Socket* socket
) {
  SocketGroupInt* self = (SocketGroupInt*)socket;

  o_log(O_LOG_ERROR, "Shouldn't call 'get_sockfd' on socket group '%s'.\n",
	self->name);
  return -1;
}

//! Return a new 'instance' structure
Socket*
socket_group_new(
  char* name
) {
  SocketGroupInt* self = (SocketGroupInt *)malloc(sizeof(SocketGroupInt));
  memset(self, 0, sizeof(SocketGroupInt));

  self->name = self->nameBuf;
  strcpy(self->name, name != NULL ? name : "UNKNOWN");

  self->sendto = sg_sendto;
  self->get_sockfd = sg_get_sockfd;

  return (Socket*)self;
}
