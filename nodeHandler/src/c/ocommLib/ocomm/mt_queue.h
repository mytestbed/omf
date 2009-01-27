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
/*! \file mt_queue.h
  \brief Header file for thread-safe queue class
  \author Max Ott (max@winlab.rutgers.edu)
 */


#ifndef O_MT_QUEUE_H
#define O_MT_QUEUE_H

struct _MTQueue;

typedef struct _MTQueue {

  //! Name used for debugging
  char* name;

} MTQueue;


/*! Create a mt_queue object.
 */ 
MTQueue*
mt_queue_new(
  char* name,   //! Name used for debugging
  int size      //! Max size of queue
);

/*! Delete queue.
 *
 */
void
mt_queue_delete(
  MTQueue* queue
);

/*! Enquee an object on queue
 *
 * Return true(1) on success, false(0) otherwise.
 */
int
mt_queue_add(
  MTQueue* queue,
  void*  obj
);

/*! Remove the oldest object from queue.
 *
 * Return object or NULL if queue is empty
 */
void*
mt_queue_remove(
  MTQueue* queue
);

/*! Return oldest object without removing from queue.
 *
 * Return object or NULL if queue is empty
 */
void*
mt_queue_peek(
  MTQueue* queue
);

/*! Check if there is still room in the queue
 *
 * Return true(1) if room, false(0) otherwise.
 */
int
mt_queue_can_add(
  MTQueue* queue
);

/*! Check if queue is empty
 *
 * Return true(1) if empty, false(0) otherwise.
 */
int
mt_queue_is_empty(
  MTQueue* queue
);

#endif
