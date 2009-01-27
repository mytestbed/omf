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
/*!\file queue.c
  \brief This file implements a FIFO queue.
*/

#include "ocomm/queue.h"
#include "ocomm/o_log.h"

#include <string.h>
#include <malloc.h>

#define OQUEUE_DONT_CARE_T 0x00
#define OQUEUE_PTR_T 0x01
#define OQUEUE_INT_T 0x02
#define OQUEUE_LONG_T 0x03
#define OQUEUE_FLOAT_T 0x04
#define OQUEUE_DOUBLE_T 0x05
#define OQUEUE_STRING_T 0x06


//! Data-structure, to store object state
typedef struct _queue {

  //! Name used for debugging
  char* name;

  int    size;     //! Number of items in queue
  int    max_size;     //! Max number of items allowed in queue

  OQueueMode mode;  //! Mode to deal with full queue behavior

  int    step;     //! Max space per queue item to reserve

  int    qlength;
  char*  queue;
  char*  head;
  char*  tail;

  //! Local memory for debug name
  char nameBuf[64];

} OQueueInt;


static int add_dats(OQueue* queue, void* data, int len, char type);
static char* remove_data(OQueue* queue, char type);

OQueue*
oqueue_new(
  char* name,
  int max_size,
  int step
) {
  OQueueInt* self = (OQueueInt *)malloc(sizeof(OQueueInt));
  memset(self, 0, sizeof(OQueueInt));

  self->mode = BLOCK_ON_FULL;
  self->step = step;
  self->qlength = max_size * self->step;
  self->queue = (void *)malloc(self->qlength);
  memset(self->queue, 0, self->qlength);
  self->max_size = max_size;
  self->head = self->tail = self->queue;

  self->name = self->nameBuf;
  strcpy(self->name, name != NULL ? name : "UNKNOWN");

  return (OQueue*)self;
}

void
oqueue_delete(
  OQueue* queue
) {
  OQueueInt* self = (OQueueInt*)queue;
  free(self->queue);
  self->name = NULL;
  free(self);
}

void
oqueue_clear(
  OQueue* queue
) {
  OQueueInt* self = (OQueueInt*)queue;
  self->head = self->tail = self->queue;
  self->size = 0;
}

/*! Enquee an object on queue. 
 *
 * Note, this just stores a reference to the object.
 *
 * Return true(1) on success, false(0) otherwise.
 */

/*! Enquee an object on queue
 *
 * Return true(1) on success, false(0) otherwise.
 */
static int
add_dats(
  OQueue* queue,
  void*   data,
  int     len,
  char    type
) {
  OQueueInt* self = (OQueueInt*)queue;

  if (self->size >= self->max_size) {
    switch (self->mode) {
    case BLOCK_ON_FULL: return 0;
    case DROP_TAIL: return 1;
    case DROP_HEAD: {
      remove_data(queue, OQUEUE_DONT_CARE_T);
      // now there should be space
      break;
    }
    default: {
      o_log(O_LOG_ERROR, "Missing implementation for queue mode.");
      return 0;
    }
    }
  }

  *self->tail = type;
  memcpy(self->tail + 1, data, len);
  self->tail += self->step;
  if (self->tail >= self->queue + self->qlength) {
    self->tail = self->queue;
  }
  self->size++;
  return 1;
}

int
oqueue_add_ptr(
  OQueue* queue,
  void*   obj
) {
  return add_dats(queue, obj, sizeof(void*), OQUEUE_PTR_T);
}

int
oqueue_add_int(
  OQueue* queue,
  int     value
) {
  int* p = &value;
  return add_dats(queue, &value, sizeof(int), OQUEUE_INT_T);
}

int
oqueue_add_long(
  OQueue* queue,
  long    value
) {
  return add_dats(queue, &value, sizeof(long), OQUEUE_LONG_T);
}

int
oqueue_add_float(
  OQueue* queue,
  float   value
) {
  return add_dats(queue, &value, sizeof(float), OQUEUE_FLOAT_T);
}

int
oqueue_add_double(
  OQueue* queue,
  double  value
) {
  return add_dats(queue, &value, sizeof(double), OQUEUE_DOUBLE_T);
}

int
oqueue_add_string(
  OQueue* queue,
  char*   string
) {
  return add_dats(queue, string, strlen(string), OQUEUE_STRING_T);
}

/*! Remove the oldest object from queue and return a reference to 
 * it. 
 *
 * Note, that this returns a pointer to the data stored
 * in the queue's internal storage. It is the receiver's 
 * responsibility to copy it to other storage if the value
 * needs to be maintained (in other words, subsequent adds
 * to the queue may override the returned value.
 *
 * Return reference to data store or NULL if queue is empty
 */
static char*
remove_data(
  OQueue* queue,
  char    type
) {
  OQueueInt* self = (OQueueInt*)queue;
  char* item = NULL;

  if (self->size <= 0) return NULL;

  if (type != OQUEUE_DONT_CARE_T && *(self->head) != type) {
    o_log(O_LOG_WARN, "Trying to read wrong type from queue '%s'\n", 
	  self->name);
    return NULL;
  }
  item = self->head + 1;
  self->head += self->step;
  if (self->head >= self->queue + self->qlength) self->head = self->queue;
  self->size--;

  return item;
}

int
oqueue_remove_ptr(
  OQueue* queue,
  void*     value
) {
  char* ptr = remove_data(queue, OQUEUE_PTR_T);

  if (ptr == NULL) return 0;
  value = (void*)ptr;
  return 1;
}

int
oqueue_remove_int(
  OQueue* queue,
  int*     value
) {
  char* ptr = remove_data(queue, OQUEUE_INT_T);

  if (ptr == NULL) return 0;
  *value = *((int*)ptr);
  return 1;
}

int
oqueue_remove_long(
  OQueue* queue,
  long*   value
) {
  char* ptr = remove_data(queue, OQUEUE_LONG_T);

  if (ptr == NULL) return 0;
  *value = *((long*)ptr);
  return 1;
}

int
oqueue_remove_float(
  OQueue* queue,
  float*  value
) {
  char* ptr = remove_data(queue, OQUEUE_FLOAT_T);

  if (ptr == NULL) return 0;
  *value = *((float*)ptr);
  return 1;
}

int
oqueue_remove_double(
  OQueue* queue,
  double*     value
) {
  char* ptr = remove_data(queue, OQUEUE_DOUBLE_T);

  if (ptr == NULL) return 0;
  *value = *((double*)ptr);
  return 1;
}

int
oqueue_remove_string(
  OQueue* queue,
  char**   value
) {
  char* ptr = remove_data(queue, OQUEUE_STRING_T);

  if (ptr == NULL) return 0;
  *value = ptr;
  return 1;
  //  return remove_data(queue, (void**)value, OQUEUE_STRING_T);
}

/*! Return oldest object without removing from queue.
 *
 * Return object or NULL if queue is empty
 */
void*
oqueue_peek(
  OQueue* queue
) {
  OQueueInt* self = (OQueueInt*)queue;

  if (self->size <= 0) return NULL;

  return self->tail + 1;
}

/*! Check if there is still room in the queue
 *
 * Return true(1) if room, false(0) otherwise.
 */
int
oqueue_can_add(
  OQueue* queue
) {
  OQueueInt* self = (OQueueInt*)queue;

  return self->size < self->max_size;
}

/*! Check if queue is empty
 *
 * Return true(1) if empty, false(0) otherwise.
 */
int
oqueue_is_empty(
  OQueue* queue
) {
  OQueueInt* self = (OQueueInt*)queue;

  return self->size == 0;
}


