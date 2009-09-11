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

#define STRSIZE		64

/*
 * Event defs
 */
typedef struct {
	int type;
	union {
		struct {
			int startdelay;	/* range in sec of start interval */
			int startat;	/* start time (alt to startdelay) */
			int pkttimeout;	/* packet timeout in usec */
			int idletimer;	/* idle timer in pkt timeouts */
			int chunkbufs;  /* max receive buffers */
			int writebufmem;/* max disk write buffer memory */
			int maxmem;	/* max total memory */
			int readahead;  /* max readahead in packets */
			int inprogress; /* max packets in progress */
			int redodelay;	/* redo delay in usec */
			int idledelay;	/* writer idle delay in usec */
			int slice;	/* disk slice to write */
			int zerofill;	/* non-0 to zero fill free space */
			int randomize;	/* non-0 to randomize request list */
			int nothreads;	/* non-0 to single thread unzip */
			int dostype;	/* DOS partition type to set */
			int debug;	/* debug level */
			int trace;	/* tracing level */
			char traceprefix[STRSIZE];
					/* prefix for trace output file */
		} start;
		struct {
			int exitstatus;
		} stop;
	} data;
} Event_t;

#define EV_ANY		0
#define EV_START	1
#define EV_STOP		2

extern int EventInit(char *server);
extern int EventCheck(Event_t *event);
extern void EventWait(int eventtype, Event_t *event);
