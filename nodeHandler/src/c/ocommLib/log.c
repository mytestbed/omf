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
/*!\file log.c
  \brief This file logging functions
*/

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdarg.h>
#include <time.h>

#include "ocomm/o_log.h"

extern int errno;

static void o_log_default(int log_level, const char* format, ...); 

static FILE* logfile;
int o_log_level = O_LOG_INFO;

o_log_fn o_log = o_log_default;

void
o_set_log_file(
  char* name
) {
  if (*name == '-') {
    logfile = NULL;
    setlinebuf(stdout);
  } else {
    logfile = fopen(name, "a");
    if (logfile == NULL) {
      fprintf(stderr, "Can't open logfile '%s'\n", name);
      return;
    }
    setvbuf ( logfile, NULL , _IOLBF , 1024 );
  }
}

void
o_set_log_level(
  int level
) {

  o_log_level = level;
}

o_log_fn 
o_set_log(
  o_log_fn new_log_fn
) {
  if ((o_log = new_log_fn) == NULL) {
    o_log = o_log_default;
  }
  return o_log;
}

void 
o_log_default(
  int log_level, 
  const char* format, 
  ...
) {

  if (log_level > o_log_level) return;

  va_list va;
  va_start(va, format);

  if (logfile == NULL) {
    switch (log_level) {
    case O_LOG_INFO:
      printf("# ");
      vprintf(format, va);
      break;
    case O_LOG_WARN:
      fprintf(stdout, "# WARN ");
      vfprintf(stdout, format, va);
      break;
    case O_LOG_ERROR:
      fprintf(stderr, "# ERROR ");
      vfprintf(stderr, format, va);
      break;
    default:
      printf("# ");
      for (; log_level > O_LOG_DEBUG; log_level--) {
	printf("..");
      }
      printf(".. ");
      vprintf(format, va);
      break;
    }
    //fflush(stdout);
  } else {

    time_t t;
    time(&t);
    struct tm* ltime = localtime(&t);

    char now[20];
    strftime(now, 20, "%b %d %H:%M:%S", ltime);

    switch (log_level) {
    case O_LOG_DEBUG:
      fprintf(logfile, "%s  DEBUG ", now);
      vfprintf(logfile, format, va);
      break;
    case O_LOG_INFO:
      fprintf(logfile, "%s  INFO  ", now);
      vfprintf(logfile, format, va);
      break;
    case O_LOG_WARN:
      fprintf(logfile, "%s  WARN  ", now);
      vfprintf(logfile, format, va);
      break;
    case O_LOG_ERROR:
      fprintf(logfile, "%s  ERROR ", now);
      vfprintf(logfile, format, va);
      break;
    default:
      fprintf(logfile, "%s  UNKNOWN ", now);
      vfprintf(logfile, format, va);
      break;
    }
  }
  va_end(va);
}

