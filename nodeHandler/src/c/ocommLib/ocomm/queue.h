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
/*! \file o_queue.h
  \brief Header file for queue library
  \author Max Ott (max@winlab.rutgers.edu)
 */


#ifndef O_QUEUE_H
#define O_QUEUE_H


typedef struct _OQueue {

  //! Name used for debugging
  char* name;

} OQueue;

typedef enum _ {
  BLOCK_ON_FULL, // Default
  DROP_TAIL,     // Silently drop any newly added items if queue is full
  DROP_HEAD      // Silently drop oldest item to make room for new one
} OQueueMode;

/*! Create a queue object.
 */ 
OQueue*
oqueue_new(
  char* name,   //! Name used for debugging
  int size,     //! Max size of queue
  int step      //! Max space per queue item to reserve
);

/*! Delete queue.
 *
 */
void
oqueue_delete(
  OQueue* queue
);

/*! Set the storage mode of this queue.
 *
 * There are three different modes:
 *
 *  BLOCK_ON_FULL  Default
 *  DROP_TAIL      Silently drop any newly added items if queue is full
 *  DROP_HEAD      Silently drop oldest item to make room for new one
 */
void
oqueue_set_mode(
  OQueue* queue,
  OQueueMode mode
);

/*! Clear the queue of all stored content.
 *
 */
void
oqueue_clear(
  OQueue* queue
);

/*! Enquee an object on queue. 
 *
 * Note, this just stores a reference to the object.
 *
 * Return true(1) on success, false(0) otherwise.
 */
int
oqueue_add_ptr(
  OQueue* queue,
  void*   obj
);

/*! Enquee a string on queue. 
 *
 * Note, this copies the string onto the queue. If a copy is
 * not necessary, use the 'oqueue_add' method.
 *
 * Return true(1) on success, false(0) otherwise.
 */
int
oqueue_add_string(
  OQueue* queue,
  char*   obj
);

/*! Enquee an integer
 *
 * Return true(1) on success, false(0) otherwise.
 */
int
oqueue_add_int(
  OQueue* queue,
  int     value
);

/*! Enquee a long
 *
 * Return true(1) on success, false(0) otherwise.
 */
int
oqueue_add_long(
  OQueue* queue,
  long    value
);

/*! Enquee a float
 *
 * Return true(1) on success, false(0) otherwise.
 */
int
oqueue_add_float(
  OQueue* queue,
  float   value
);

/*! Enquee a double
 *
 * Return true(1) on success, false(0) otherwise.
 */
int
oqueue_add_double(
  OQueue* queue,
  double  value
);

/*! Remove the oldest object from queue.
 *
 * Return object or NULL if queue is empty
 */
void*
oqueue_remove(
  OQueue* queue
);

/*! Remove a string from queue. 
 *
 * Note, that this returns a pointer to the data stored
 * in the queue's internal storage. It is the receiver's 
 * responsibility to copy it to other storage if the value
 * needs to be maintained (in other words, subsequent adds
 * to the queue may override the returned value.
 *
 * Return reference to data store or NULL if queue is empty
 */
int
oqueue_remove_string(
  OQueue* queue,
  char**  string
);

/*! Remove an integer
 *
 * Return oldest value stored on queue in 'value'.
 *
 * Return true(1) on success, of false(0) if queue was empty.
 */
int
oqueue_remove_int(
  OQueue* queue,
  int*    value
);

/*! Remove a long
 *
 * Return oldest value stored on queue in 'value'.
 *
 * Return true(1) on success, of false(0) if queue was empty.
 */
int
oqueue_remove_long(
  OQueue* queue,
  long*   value
);

/*! Remove a float
 *
 * Return oldest value stored on queue in 'value'.
 *
 * Return true(1) on success, of false(0) if queue was empty.
 */
int
oqueue_remove_float(
  OQueue* queue,
  float*  value
);

/*! Remove a double
 *
 * Return oldest value stored on queue in 'value'.
 *
 * Return true(1) on success, of false(0) if queue was empty.
 *
 */
int
oqueue_remove_double(
  OQueue* queue,
  double* value
);

/*! Return oldest object without removing from queue.
 *
 * Return object or NULL if queue is empty
 */
void*
oqueue_peek(
  OQueue* queue
);

/*! Check if there is still room in the queue
 *
 * Return true(1) if room, false(0) otherwise.
 */
int
oqueue_can_add(
  OQueue* queue
);

/*! Check if queue is empty
 *
 * Return true(1) if empty, false(0) otherwise.
 */
int
oqueue_is_empty(
  OQueue* queue
);

#endif
