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

#include "ocomm/mt_queue.h"
#include "ocomm/queue.h"
#include "ocomm/o_log.h"

#include <string.h>
#include <malloc.h>
#include <pthread.h>
#include <errno.h>


//! Data-structure, to store object state
typedef struct _mt_queue {

  //! Name used for debugging
  char* name;

  OQueue* queue;

  pthread_mutex_t mutex;
  pthread_cond_t  writeCondVar;
  pthread_cond_t  readCondVar;


  //! Local memory for debug name
  char nameBuf[64];

} MTQueueInt;

static int lock(MTQueueInt* self);
static void unlock(MTQueueInt* self);

MTQueue*
mt_queue_new(
  char* name,
  int length
) {
  MTQueueInt* self = (MTQueueInt *)malloc(sizeof(MTQueueInt));
  memset(self, 0, sizeof(MTQueueInt));

  self->queue = oqueue_new(name, length, sizeof(void*));

  pthread_mutex_init(&self->mutex, NULL); 
  pthread_cond_init(&self->writeCondVar, NULL);
  pthread_cond_init(&self->readCondVar, NULL);

  self->name = self->nameBuf;
  strcpy(self->name, name != NULL ? name : "UNKNOWN");

  return (MTQueue*)self;
}

void
mt_queue_delete(
  MTQueue* queue
) {
  MTQueueInt* self = (MTQueueInt*)queue;
  free(self->queue);
  pthread_mutex_destroy(&self->mutex);
  pthread_cond_destroy(&self->writeCondVar);
  pthread_cond_destroy(&self->readCondVar);
  self->name = NULL;
  free(self);
}


/*! Enquee an object on queue
 *
 * Return true(1) on success, false(0) otherwise.
 */
int
mt_queue_add(
  MTQueue* queue,
  void*  obj
) {
  MTQueueInt* self = (MTQueueInt*)queue;
  int res;

  if (!lock(self)) return 0;
  int rc = 0;
  while(rc != 0 || !oqueue_add_ptr(self->queue, obj)) {
    rc = pthread_cond_wait(&self->writeCondVar, &self->mutex);
  }
  unlock(self);

  if (pthread_cond_signal(&self->readCondVar)) {
    o_log(O_LOG_WARN, "%s: Couldn't signal read condVar (%s)\n", 
	  self->name, strerror(errno));
    return 0;
  }
  return 1;
}

/*! Remove the oldest object from queue.
 *
 * Return object or NULL if queue is empty
 */
void*
mt_queue_remove(
  MTQueue* queue
) {
  MTQueueInt* self = (MTQueueInt*)queue;
  void* res;

  if (!lock(self)) return 0;
  int rc = 0;
  while(rc != 0 || oqueue_remove_ptr(self->queue, &res) == 0) {
    rc = pthread_cond_wait(&self->readCondVar, &self->mutex);
  }
  unlock(self);

  if (pthread_cond_signal(&self->writeCondVar)) {
    o_log(O_LOG_WARN, "%s: Couldn't signal write condVar (%s)\n", 
	  self->name, strerror(errno));
    return 0;
  }
  return res;
}


/*! Return oldest object without removing from queue.
 *
 * Return object or NULL if queue is empty
 */
void*
mt_queue_peek(
  MTQueue* queue
) {
  MTQueueInt* self = (MTQueueInt*)queue;
  void* res;

  if (!lock(self)) return 0;
  res = oqueue_peek(self->queue);
  unlock(self);
  return res;
}


/*! Check if there is still room in the queue
 *
 * Return true(1) if room, false(0) otherwise.
 */
int
mt_queue_can_add(
  MTQueue* queue
) {
  MTQueueInt* self = (MTQueueInt*)queue;
  int res;

  if (!lock(self)) return 0;
  res = oqueue_can_add(self->queue);
  unlock(self);
  return res;
}

/*! Check if queue is empty
 *
 * Return true(1) if empty, false(0) otherwise.
 */
int
mt_queue_is_empty(
  MTQueue* queue
) {
  MTQueueInt* self = (MTQueueInt*)queue;
  int res;

  if (!lock(self)) return 0;
  res = oqueue_is_empty(self->queue);
  unlock(self);
  return res;
}

int
lock(
  MTQueueInt* self
) {
  if (pthread_mutex_lock(&self->mutex)) {
    o_log(O_LOG_WARN, "%s: Couldn't get mutex lock (%s)\n", 
	  self->name, strerror(errno));
    return 0;
  }
  return 1;
}

void
unlock(
  MTQueueInt* self
) {
  pthread_mutex_unlock(&self->mutex);
}
