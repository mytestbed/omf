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
/*! \file o_eventloop.h
  \brief Header file central eventloop
  \author Max Ott (max@winlab.rutgers.edu)
 */


#ifndef O_EVENTLOOP_H
#define O_EVENTLOOP_H

#include <ocomm/o_socket.h>

typedef struct _TimerEvtSource {

  //! Name used for debugging
  char* name;

} TimerEvtSource;

typedef struct _sockEvtSource {

  //! Name used for debugging
  char* name;
  
  //! Associated socket
  Socket* socket;

} SockEvtSource;


#include <time.h>
#include <ocomm/o_socket.h>


/*! Defines the signature of a socket related callback function
 *  from the eventloop. This reports data read from socket.
 */ 
typedef void (*o_el_read_socket_callback)(SockEvtSource* source, void* handle, 
				     void* buffer, int buf_size); 


/*! Defines the signature of a socket related callback function
 *  from the eventloop. This just informs us that the socket is readable.
 */ 
typedef void (*o_el_monitor_socket_callback)(SockEvtSource* source, void* handle);


typedef enum _SockStatus {
  SOCKET_WRITEABLE,
  SOCKET_CONN_CLOSED,
  SOCKET_CONN_REFUSED,
  SOCKET_DROPPED,  //! Socket monitoring dropped by eventloop
  SOCKET_UNKNOWN
} SocketStatus;

/*! Defines the signature of a socket related callback function
 *  from the eventloop. This informs us of any state changes.
 */ 
typedef void (*o_el_state_socket_callback)(SockEvtSource* source, 
					   SocketStatus status, 
					   int errno,
					   void* handle);





/*! Defines the signature of a socket related callback function
 *  from the eventloop.
 */ 
typedef void (*o_el_timer_callback)(TimerEvtSource* source, void* handle);


/*! Initialize eventloop
 */ 
void 
eventloop_init();

/*! Start eventloop. Will not return until ???
 */
void 
eventloop_run();


/*! Register a new input channel with the event loop.
 * Read from channel when data arrives and call
 * callback with read data.
 */ 
SockEvtSource*
eventloop_on_read_in_channel(
  Socket* socket,
  o_el_read_socket_callback data_callback,
  o_el_state_socket_callback status_callback,
  void* handle
);

/*! Register a new input channel with the event loop.
 * Call callback when channel is readable
 */ 
SockEvtSource*
eventloop_on_monitor_in_channel(
  Socket* socket,
  o_el_monitor_socket_callback data_callback,
  o_el_state_socket_callback status_callback,
  void* handle
);

/*! Register callback if 'socket' can be written to
SockEvtSource*
eventloop_on_out_channel(
  Socket* socket,
  o_el_state_socket_callback status_cbk,
  void* handle
);

/*! Register stdin with the event loop.
 */ 
SockEvtSource*
eventloop_on_stdin(
  o_el_read_socket_callback callback,
  void* handle
);

/*! Set activit flag of 'source' according to boolean 'flag'.
 */ 
void
eventloop_socket_activate(
  SockEvtSource* source,
  int flag
);


/*! Remove 'source' from being monitored.
 */ 
void
eventloop_socket_remove(
  SockEvtSource* source
);



TimerEvtSource*
eventloop_every(
  char* name,
  int period,
  o_el_timer_callback callback,
  void* handle
);

/*! Return the current time */
time_t 
eventloop_now();


void
timer_stop(
  TimerEvtSource* timer
);

#endif
