/*
 * Copyright (c) 2002, 2003 University of Utah and the Flux Group.
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

#include <pthread.h>
#include <sys/time.h>
#include <netinet/in.h>

#ifdef NEVENTS
struct event {
	struct timeval	tstamp;
	struct in_addr	srcip;
	int		event;
	unsigned long	args[4];
};

extern struct event eventlog[];
extern struct event *evptr, *evend;
extern int evlogging, evcount;
extern pthread_mutex_t evlock;

#define EVENT(l, e, ip, a1, a2, a3, a4) \
if (evlogging >= (l)) { \
	pthread_mutex_lock(&evlock); \
	gettimeofday(&evptr->tstamp, 0); \
	evptr->event = (e); \
	evptr->srcip = (ip); \
	evptr->args[0] = (unsigned long)(a1); \
	evptr->args[1] = (unsigned long)(a2); \
	evptr->args[2] = (unsigned long)(a3); \
	evptr->args[3] = (unsigned long)(a4); \
	if (++evptr == evend) evptr = eventlog; \
	evcount++; \
	pthread_mutex_unlock(&evlock); \
}

#define CLEVENT(l, e, a1, a2, a3, a4) \
if (evlogging >= (l)) { \
	extern struct in_addr myipaddr; \
	pthread_mutex_lock(&evlock); \
	gettimeofday(&evptr->tstamp, 0); \
	evptr->event = (e); \
	evptr->srcip = myipaddr; \
	evptr->args[0] = (unsigned long)(a1); \
	evptr->args[1] = (unsigned long)(a2); \
	evptr->args[2] = (unsigned long)(a3); \
	evptr->args[3] = (unsigned long)(a4); \
	if (++evptr == evend) evptr = eventlog; \
	evcount++; \
	pthread_mutex_unlock(&evlock); \
}

#define EV_JOINREQ	1
#define EV_JOINREP	2
#define EV_LEAVEMSG	3
#define EV_REQMSG	4
#define EV_BLOCKMSG	5
#define EV_WORKENQ	6
#define EV_WORKDEQ	7
#define EV_READFILE	8
#define EV_WORKOVERLAP	9
#define EV_WORKMERGE	10

#define EV_CLIREQ	12
#define EV_OCLIMSG	13
#define EV_CLINOROOM	14
#define EV_CLIDUPCHUNK	15
#define EV_CLIDUPBLOCK	16
#define EV_CLISCHUNK	17
#define EV_CLIECHUNK	18
#define EV_CLILCHUNK	19
#define EV_CLIREQCHUNK	20
#define EV_CLIREQRA	21
#define EV_CLIJOINREQ	22
#define EV_CLIJOINREP	23
#define EV_CLILEAVE	24
#define EV_CLIREQMSG	25
#define EV_CLISTAMP	26
#define EV_CLIWRSTART	27
#define EV_CLIWRDONE	28
#define EV_CLIWRIDLE	29
#define EV_CLIBLOCK	30
#define EV_CLISTART	31
#define EV_CLIGOTPKT	32
#define EV_CLIRTIMO	33
#define EV_PREQMSG	34
#define EV_CLIPREQ	35
#define EV_CLIPREQMSG	36
#define EV_REQRANGE	37
#define EV_OVERRUN	38
#define EV_LONGBURST	39
#define EV_DUPCHUNK	40

#define EV_MAX		40

extern void ClientTraceInit(char *file);
extern void ClientTraceReinit(char *file);
extern void ServerTraceInit(char *file);
extern void TraceStart(int level);
extern void TraceStop(void);
extern void TraceDump(void);
#else
#define EVENT(l, e, ip, a1, a2, a3, a4)
#define CLEVENT(l, e, a1, a2, a3, a4)
#define ClientTraceInit(file)
#define ClientTraceReinit(file)
#define ServerTraceInit(file)
#define TraceStart(level)
#define TraceStop()
#define TraceDump()
#endif
