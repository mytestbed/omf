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
/*! \file o_socket.h
  \brief Header file for socket library
  \author Max Ott (max@winlab.rutgers.edu)
 */


#ifndef O_SOCKET_H
#define O_SOCKET_H

struct _Socket;

/*! Send a message through the socket
 *
 * Return 0 on success, -1 otherwise
 */
typedef int (*o_socket_sendto)(struct _Socket* socket, char* buf, int buf_size);


/*! Return the file descripter associated with this socket
 *
 * Return socket's fd, -1 otherwise
 */
typedef int (*o_get_sockfd)(struct _Socket* socket);

typedef struct _Socket {

  //! Name used for debugging
  char* name;

  //! Function to send message through this socket
  o_socket_sendto sendto;

  //! Socket file descriptor of the communication socket created to send/receive.
  o_get_sockfd get_sockfd;

  //int sockfd;

} Socket;

/*! Defines the signature of a callback to report a new IN socket
 * from a client connecting to a listening socket.
 */ 
typedef void (*o_so_connect_callback)(Socket* newSock, void* handle);


/*! Create an unbound socket object.
 */ 
Socket*
socket_new(
  char* name,   //! Name used for debugging
  int is_tcp  //! True if TCP, false for UDP
);

/*! Create an IP socket bound to ADDR and PORT object.
 */ 
Socket*
socket_in_new(
  char* name,   //! Name used for debugging
  int port, //! Port used 
  int is_tcp  //! True if TCP, false for UDP
);

/*! Create a multicast socket object.
 */ 
Socket*
socket_mc_in_new(
  char* name,   //! Name used for debugging
  char* addr,   //! IP address of the multicast socket/channel.
  int port, //! Port used 
  char* iface
);

/*! Create a multicast socket object.
 */ 
Socket*
socket_mc_out_new(
  char* name,   //! Name used for debugging
  char* addr,   //! IP address of the multicast socket/channel.
  int port, //! Port used 
  char* iface //! Name of the interface (eth0/eth1) to bind to
);

/*! Create a server socket object.
 */ 
Socket*
socket_server_new(
  char* name,   //! Name used for debugging
  int port, //! Port to listen on 
  o_so_connect_callback callback, //! Called when new client connects
  void* handle //! opaque argument to callback
);

/*! Create a outgoing TCP socket object.
 */ 
Socket*
socket_tcp_out_new(
  char* name,   //! Name used for debugging
  char* addr,   //! IP address of the server to connect to.
  int port //! Port of remote service 
);

/*! Attempt to reconnect.
 *
 * Return true(1) on success, false(0) otherwise.
 */
int
socket_reconnect(
  Socket* socket
);

/*! Close the communication channel.
 * Return 0 on success, -1 otherwise
 */
int
socket_close(
  Socket* socket
);

/*! Method for closing ALL communication channels
 * Return 0 on success, -1 otherwise
 */
int
socket_close_all();


/*! Send a message through the socket
 *
 * Return 0 on success, -1 otherwise
 */
int
socket_sendto(
  Socket* socket,
  char* buf,
  int buf_size
);

/*! Return the file descripter associated with this socket
 *
 * Return socket's fd, -1 otherwise
 */
int
socket_get_sockfd(
  Socket* socket
);

/*! Return the address of this socket. */
/*
char*
socket_get_addr(
  Socket* socket
);
*/

#endif
