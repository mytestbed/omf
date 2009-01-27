/*!\file queue.c
  \brief testing the queue
*/

#include <popt.h>
#include <stdio.h>
#include <strings.h>
#include <string.h>
#include <stdlib.h>
#include <sys/errno.h>
#include <assert.h>

#include "ocomm/queue.h"

// Filling and emptying a queue
test1()

{
  OQueue* q = oqueue_new("test1", 3, 20);
  oqueue_add_string(q, "one");
  oqueue_add_string(q, "two");
  char* s1;  oqueue_remove_string(q, &s1);
  char* s2;  oqueue_remove_string(q, &s2);
  printf("t1: Removed '%s' before '%s'\n", s1, s2);
}

// Checking wrap
test2()

{
  OQueue* q = oqueue_new("test1", 3, 20);
  oqueue_add_string(q, "one");
  oqueue_add_string(q, "two");
  char* s1;  oqueue_remove_string(q, &s1);
  char* s2;  oqueue_remove_string(q, &s2);
  oqueue_add_string(q, "one");
  oqueue_add_string(q, "two");
  oqueue_remove_string(q, &s1);
  oqueue_remove_string(q, &s2);
  printf("t1: Removed '%s' before '%s'\n", s1, s2);
}

// Checking full check
test3()

{
  OQueue* q = oqueue_new("test1", 3, 20);
  int r1 = oqueue_add_string(q, "one");
  int r2 = oqueue_add_string(q, "two");
  int r3 = oqueue_add_string(q, "three");
  int r4 = oqueue_add_string(q, "four");
  printf("t3: Tried to add 4 items to list of 3. Result %d %d %d %d\n", 
	 r1, r2, r3, r4);
  char* s1; oqueue_remove_string(q, &s1);
  printf("t3: First remove should be 'one': '%s'\n", s1);
}

// Checking different types;
test4()

{
  OQueue* q = oqueue_new("test1", 5, 20);
  oqueue_add_int(q, 1111111111);
  int io; oqueue_remove_int(q, &io);
  printf("t4: Removed '%i'\n", io);
}

// Checking different types;
test5()

{
  OQueue* q = oqueue_new("test1", 5, 20);
  oqueue_add_int(q, 1111111111);
  //  long int li = 2222222222L;
  long li = 222222222L;
  oqueue_add_long(q, li);
  oqueue_add_float(q, 333.333);
  oqueue_add_double(q, 4.444444444444444444444444444); 
  int io; oqueue_remove_int(q, &io);
  long lo; oqueue_remove_long(q, &lo);
  float fo; oqueue_remove_float(q, &fo);
  double dou; oqueue_remove_double(q, &dou);

  printf("t5: Removed '%d'(%d), '%ld'(%d), '%f', '%e'\n", 
	 io, sizeof(io), lo, sizeof(lo), fo, dou);
}

int
main(
  int argc,
  const char *argv[]
) {
  test1();
  test2();
  test3();
  test4();
  test5();
}
