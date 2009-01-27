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
/*! \file o_socket_group.h
  \brief Header file for socket groups
  \author Max Ott (max@winlab.rutgers.edu)
 */


#ifndef O_SOCKET_GROUP_H
#define O_SOCKET_GROUP_H



/*! Create an new socket group.
 */ 
Socket*
socket_group_new(
  char* name   //! Name used for debugging
);

/*! Add a socket to the group.
 */ 
void
socket_group_add(
  Socket* this,   //! This object
  Socket* socket  //! Socket to add
);

/*! Remove a socket to the group.
 */ 
void
socket_group_remove(
  Socket* this,   //! This object
  Socket* socket  //! Socket to remove
);




#endif
