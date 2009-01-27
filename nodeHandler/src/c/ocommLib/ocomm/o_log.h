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
/*! \file o_log.h
  \brief Header file for generic log functions
  \author Max Ott (max@winlab.rutgers.edu)
 */


#ifndef O_LOG_H
#define O_LOG_H

#define O_LOG_ERROR 1
#define O_LOG_WARN  2
#define O_LOG_INFO  3
#define O_LOG_DEBUG 4
#define O_LOG_DEBUG2 5
#define O_LOG_DEBUG3 6
#define O_LOG_DEBUG4 7

typedef void (*o_log_fn)(int log_level, const char* format, ...); 
extern o_log_fn o_log;

/*! \fn o_log_fn o_set_log(o_log_fn log_fn)
  \brief Set the log function, or if NULL return the default function.
  \param log_fn Function to use for logging
*/
o_log_fn 
o_set_log(o_log_fn log_fn);

/*! \fn void o_set_log_file(char* name)
  \brief Set the file to send log messages to, '-' for stdout
  \param name Name of logfile
*/
void
o_set_log_file(char* name);

/*! \fn void o_set_log_level(int level)
  \brief Set the level at which to print log message.
  \param level Level at which to start printing log messages
*/
void
o_set_log_level(int level);

#endif
