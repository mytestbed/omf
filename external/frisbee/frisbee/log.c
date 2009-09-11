/*
 * Copyright (c) 2000-2003 University of Utah and the Flux Group.
 * All rights reserved.
 * 
 * This file is part of Frisbee, which is part of the Netbed/Emulab Network
 * Testbed.  Frisbee is free software, also known as "open source;" you can
 * redistribute it and/or modify it under the terms of the GNU General
 * Public License (GPL), version 2, as published by the Free Software
 * Foundation (FSF).  To explore alternate licensing terms, contact the
 * University of Utah at flux-dist@cs.utah.edu or +1-801-585-3271.
 * 
 * Frisbee is distributed in the hope that it will be useful, but WITHOUT
 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
 * FITNESS FOR A PARTICULAR PURPOSE.  See the GPL for more details.  You
 * should have received a copy of the GPL along with Frisbee; see the file
 * COPYING.  If not, write to the FSF, 59 Temple Place #330, Boston, MA
 * 02111-1307, USA, or look at http://www.fsf.org/copyleft/gpl.html .
 */

/*
 * Logging and debug routines.
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <syslog.h>
#include <assert.h>
#include <errno.h>
#include "decls.h"

#ifndef LOG_TESTBED
#define LOG_TESTBED	LOG_USER
#endif

static int usesyslog = 1;

/*
 * There is really no point in the client using syslog, but its nice
 * to use the same log functions either way.
 */
int
ClientLogInit(void)
{
	usesyslog = 0;
	return 0;
}

int
ServerLogInit(void)
{
	if (debug) {
		usesyslog = 0;
		return 1;
	}

	openlog("frisbeed", LOG_PID, LOG_TESTBED);

	return 0;
}

void
log(const char *fmt, ...)
{
	va_list args;
	char	buf[BUFSIZ];

	va_start(args, fmt);
	vsnprintf(buf, sizeof(buf), fmt, args);
	va_end(args);

	if (!usesyslog) {
		/*
		fputs(buf, stderr);
		fputc('\n', stderr);
		*/
	}
	else
		syslog(LOG_INFO, "%s", buf);
}

void
warning(const char *fmt, ...)
{
	va_list args;

	va_start(args, fmt);
	if (!usesyslog) {
		vfprintf(stderr, fmt, args);
		fputc('\n', stderr);
		fflush(stderr);
	}
	else
		vsyslog(LOG_WARNING, fmt, args);
	       
	va_end(args);
}

void
error(const char *fmt, ...)
{
	va_list args;

	va_start(args, fmt);
	if (!usesyslog) {
		vfprintf(stderr, fmt, args);
		fflush(stderr);
	}
	else
		vsyslog(LOG_ERR, fmt, args);
	       
	va_end(args);
}

void
fatal(const char *fmt, ...)
{
	va_list args;

	va_start(args, fmt);
	if (!usesyslog) {
		vfprintf(stderr, fmt, args);
		fputc('\n', stderr);
		fflush(stderr);
	}
	else
		vsyslog(LOG_ERR, fmt, args);
	       
	va_end(args);
	exit(-1);
}

void
pwarning(const char *fmt, ...)
{
	va_list args;
	char	buf[BUFSIZ];

	va_start(args, fmt);
	vsnprintf(buf, sizeof(buf), fmt, args);
	va_end(args);

	warning("%s : %s", buf, strerror(errno));
}

void
pfatal(const char *fmt, ...)
{
	va_list args;
	char	buf[BUFSIZ];

	va_start(args, fmt);
	vsnprintf(buf, sizeof(buf), fmt, args);
	va_end(args);

	fatal("%s : %s", buf, strerror(errno));
}
