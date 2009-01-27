/*!\file mt_queue.c
  \brief testing the thread-safe queue
*/

#include <popt.h>
#include <stdio.h>
#include <strings.h>
#include <string.h>
#include <stdlib.h>
#include <sys/errno.h>
#include <assert.h>

#include "ocomm/mt_queue.h"

// Slow producer
slow_producer(
  MTQueue* q
) {
  int i;

  for (i = 0; i < 5; i++) {
    char* s = malloc(16);
    sprintf(s, "token_%i", i);
    printf("sp: Adding '%s'\n", s);
    mt_queue_add(q, s);
    sleep(1);
  }
}

fast_consumer(
  MTQueue* q,
  int samples
) {
  int i;

  for (i = 0; i < samples; i++) {
    void* res;
    res = mt_queue_remove(q);
    printf("fc: Removing '%s'\n", res);
  }
}

void 
test1()

{
  MTQueue* q;
  pthread_t  thread; 

  puts("-- TEST 1 --");
  q = mt_queue_new("Q", 3);
  pthread_create(&thread, NULL, slow_producer, (void*)q);
  fast_consumer(q, 5);
}

// Slow producer
fast_producer(
  MTQueue* q
) {
  int i;

  for (i = 0; i < 5; i++) {
    char* s = malloc(16);
    sprintf(s, "token_%i", i);
    printf("fp: Starting to add '%s'\n", s);
    mt_queue_add(q, s);
    printf("fp: Done adding '%s'\n", s);
  }
}

slow_consumer(
  MTQueue* q,
  int samples
) {
  int i;

  for (i = 0; i < samples; i++) {
    void* res;
    res = mt_queue_remove(q);
    printf("sc: Removing '%s'\n", res);
    sleep(1);
  }
}

void 
test2()

{
  MTQueue* q;
  pthread_t  thread; 

  puts("-- TEST 2 --\n");
  q = mt_queue_new("Q", 3);
  pthread_create(&thread, NULL, fast_producer, (void*)q);
  slow_consumer(q, 5);
}

int
main(
  int argc,
  const char *argv[]
) {
  test1();
  test2();
}
