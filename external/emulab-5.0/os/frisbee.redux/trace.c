/*
 * Copyright (c) 2002, 2003, 2004 University of Utah and the Flux Group.
 * All rights reserved.
 * This file is part of the Emulab network testbed software.
 * 
 * Emulab is free software, also known as "open source;" you can
 * redistribute it and/or modify it under the terms of the GNU Affero
 * General Public License as published by the Free Software Foundation,
 * either version 3 of the License, or (at your option) any later version.
 * 
 * Emulab is distributed in the hope that it will be useful, but WITHOUT ANY
 * WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
 * FOR A PARTICULAR PURPOSE.  See the GNU Affero General Public License for
 * more details, which can be found in the file AGPL-COPYING at the root of
 * the source tree.
 * 
 * You should have received a copy of the GNU Affero General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

#include <stdio.h>
#include <stdlib.h>
#include <fcntl.h>
#include <netinet/in.h>
#include <arpa/inet.h>

#include "decls.h"
#include "trace.h"
#include "log.h"

#ifdef NEVENTS

struct event eventlog[NEVENTS];
struct event *evptr = eventlog;
struct event *evend = &eventlog[NEVENTS];
int evlogging, evcount;
pthread_mutex_t evlock;
static int evisclient;
static FILE *fd;
static struct timeval startt;

static void
TraceInit(char *file)
{
	static int called;

	if (file) {
		fd = fopen(file, "a+");
		if (fd == NULL)
			pfatal("Cannot open logfile %s", file);
	} else
		fd = stderr;

	if (!called) {
		called = 1;
		pthread_mutex_init(&evlock, 0);
	}
}

void
ClientTraceInit(char *prefix)
{
	extern struct in_addr myipaddr;

	evlogging = 0;

	if (fd != NULL && fd != stderr)
		fclose(fd);
	memset(eventlog, 0, sizeof eventlog);
	evptr = eventlog;
	evcount = 0;

	if (prefix && prefix[0]) {
		char name[64];
		snprintf(name, sizeof(name),
			 "%s-%s.trace", prefix, inet_ntoa(myipaddr));
		TraceInit(name);
	} else
		TraceInit(0);

	evisclient = 1;
}

void
ServerTraceInit(char *file)
{
	extern struct in_addr myipaddr;

	if (file) {
		char name[64];
		snprintf(name, sizeof(name),
			 "%s-%s.trace", file, inet_ntoa(myipaddr));
		TraceInit(name);
	} else
		TraceInit(0);

	evisclient = 0;
}

void
TraceStart(int level)
{
	evlogging = level;
	gettimeofday(&startt, 0);
}

void
TraceStop(void)
{
	evlogging = 0;
}

void
TraceDump(void)
{
	struct event *ptr;
	int done = 0;
	struct timeval stamp;
	int oevlogging = evlogging;

	evlogging = 0;
	ptr = evptr;
	do {
		if (ptr->event > 0 && ptr->event <= EV_MAX) {
			if (!done) {
				done = 1;
				fprintf(fd, "%d of %d events, "
					"start: %ld.%03ld:\n",
					evcount > NEVENTS ? NEVENTS : evcount,
					evcount, (long)startt.tv_sec,
					startt.tv_usec/1000);
			}
			timersub(&ptr->tstamp, &startt, &stamp);
			fprintf(fd, " +%03ld.%03ld: ",
				(long)stamp.tv_sec, stamp.tv_usec/1000);
			switch (ptr->event) {
			case EV_JOINREQ:
				fprintf(fd, "%s: JOIN request, ID=%lx\n",
					inet_ntoa(ptr->srcip), ptr->args[0]);
				break;
			case EV_JOINREP:
				fprintf(fd, "%s: JOIN reply, blocks=%lu\n",
					inet_ntoa(ptr->srcip), ptr->args[0]);
				break;
			case EV_LEAVEMSG:
				fprintf(fd, "%s: LEAVE msg, ID=%lx, time=%lu\n",
					inet_ntoa(ptr->srcip),
					ptr->args[0], ptr->args[1]);
				break;
			case EV_REQMSG:
				fprintf(fd, "%s: REQUEST msg, %lu[%lu-%lu]\n",
					inet_ntoa(ptr->srcip), 
					ptr->args[0], ptr->args[1],
					ptr->args[1]+ptr->args[2]-1);
				break;
			case EV_PREQMSG:
				fprintf(fd, "%s: PREQUEST msg, %lu(%lu)%s\n",
					inet_ntoa(ptr->srcip), ptr->args[0],
					ptr->args[1],
					ptr->args[2] ? " [RETRY]" : "");
				break;
			case EV_OVERRUN:
				stamp.tv_sec = ptr->args[0];
				stamp.tv_usec = ptr->args[1];
				timersub(&ptr->tstamp, &stamp, &stamp);
				fprintf(fd, "overrun by %lu.%03lu "
					"after %lu[%lu]\n",
					stamp.tv_sec, stamp.tv_usec/1000,
					ptr->args[2], ptr->args[3]);
				break;
			case EV_LONGBURST:
				fprintf(fd, "finished long burst %lu (>%lu) "
					"after %lu[%lu]\n",
					ptr->args[0], ptr->args[1],
					ptr->args[2], ptr->args[3]);
				break;
			case EV_BLOCKMSG:
				fprintf(fd, "sent block, %lu[%lu], retry=%lu\n",
					ptr->args[0], ptr->args[1],
					ptr->args[2]);
				break;
			case EV_WORKENQ:
				fprintf(fd, "enqueues, %lu(%lu), "
					"%lu ents\n",
					ptr->args[0], ptr->args[1],
					ptr->args[2]);
				break;
			case EV_WORKDEQ:
				fprintf(fd, "dequeues, %lu[%lu-%lu], "
					"%lu ents\n",
					ptr->args[0], ptr->args[1],
					ptr->args[1]+ptr->args[2]-1,
					ptr->args[3]);
				break;
			case EV_WORKOVERLAP:
				fprintf(fd, "queue overlap, "
					"old=[%lu-%lu], new=[%lu-%lu]\n",
					ptr->args[0],
					ptr->args[0]+ptr->args[1]-1,
					ptr->args[2],
					ptr->args[2]+ptr->args[3]-1);
				break;
			case EV_WORKMERGE:
				if (ptr->args[3] == ~0)
					fprintf(fd, "merged %lu with current\n",
						ptr->args[0]);
				else
					fprintf(fd, "merged %lu at ent %lu, "
						"added %lu to existing %lu\n",
						ptr->args[0], ptr->args[3],
						ptr->args[2], ptr->args[1]);
				break;
			case EV_DUPCHUNK:
				fprintf(fd, "possible dupchunk %lu\n",
					ptr->args[0]);
				break;
			case EV_READFILE:
				stamp.tv_sec = ptr->args[2];
				stamp.tv_usec = ptr->args[3];
				timersub(&ptr->tstamp, &stamp, &stamp);
				fprintf(fd, "readfile, %lu@%lu, %lu.%03lus\n",
					ptr->args[1], ptr->args[0],
					stamp.tv_sec, stamp.tv_usec/1000);
				break;


			case EV_CLISTART:
				fprintf(fd, "%s: starting\n",
					inet_ntoa(ptr->srcip));
				break;
			case EV_OCLIMSG:
			{
				struct in_addr ipaddr = { ptr->args[0] };

				fprintf(fd, "%s: got %s msg, ",
					inet_ntoa(ptr->srcip),
					(ptr->args[1] == PKTSUBTYPE_JOIN ?
					 "JOIN" : "LEAVE"));
				fprintf(fd, "ip=%s\n", inet_ntoa(ipaddr));
				break;
			}
			case EV_CLIREQMSG:
			{
				struct in_addr ipaddr = { ptr->args[0] };

				fprintf(fd, "%s: saw REQUEST for ",
					inet_ntoa(ptr->srcip));
				fprintf(fd, "%lu[%lu-%lu], ip=%s\n",
					ptr->args[1], ptr->args[2],
					ptr->args[2]+ptr->args[3]-1,
					inet_ntoa(ipaddr));
				break;
			}
			case EV_CLIPREQMSG:
			{
				struct in_addr ipaddr = { ptr->args[0] };

				fprintf(fd, "%s: saw PREQUEST for ",
					inet_ntoa(ptr->srcip));
				fprintf(fd, "%lu, ip=%s\n",
					ptr->args[1], inet_ntoa(ipaddr));
				break;
			}
			case EV_CLINOROOM:
				fprintf(fd, "%s: block %lu[%lu], no room, "
					"dropped %lu blocks of previous\n",
					inet_ntoa(ptr->srcip),
					ptr->args[0], ptr->args[1],
					ptr->args[2]);
				break;
			case EV_CLIDUPCHUNK:
				fprintf(fd, "%s: block %lu[%lu], dup chunk\n",
					inet_ntoa(ptr->srcip),
					ptr->args[0], ptr->args[1]);
				break;
			case EV_CLIDUPBLOCK:
				fprintf(fd, "%s: block %lu[%lu], dup block\n",
					inet_ntoa(ptr->srcip),
					ptr->args[0], ptr->args[1]);
				break;
			case EV_CLIBLOCK:
				fprintf(fd, "%s: block %lu[%lu], remaining=%lu\n",
					inet_ntoa(ptr->srcip),
					ptr->args[0], ptr->args[1],
					ptr->args[2]);
				break;
			case EV_CLISCHUNK:
				fprintf(fd, "%s: start chunk %lu, block %lu, "
					"%lu chunks in progress\n",
					inet_ntoa(ptr->srcip),
					ptr->args[0], ptr->args[1],
					ptr->args[2]);
				break;
			case EV_CLIECHUNK:
				fprintf(fd, "%s: end chunk %lu, block %lu, "
					"%lu chunks in progress\n",
					inet_ntoa(ptr->srcip),
					ptr->args[0], ptr->args[1],
					ptr->args[2]);
				break;
			case EV_CLILCHUNK:
				fprintf(fd, "%s: switched from incomplete "
					"chunk %lu at block %lu "
					"(%lu blocks to go)\n",
					inet_ntoa(ptr->srcip),
					ptr->args[0], ptr->args[1],
					ptr->args[2]);
				break;
			case EV_CLIREQ:
				fprintf(fd, "%s: send REQUEST, %lu[%lu-%lu]\n",
					inet_ntoa(ptr->srcip),
					ptr->args[0], ptr->args[1],
					ptr->args[1]+ptr->args[2]-1);
				break;
			case EV_CLIPREQ:
				fprintf(fd, "%s: send PREQUEST, %lu(%lu)\n",
					inet_ntoa(ptr->srcip), ptr->args[0],
					ptr->args[1]);
				break;
			case EV_CLIREQCHUNK:
				fprintf(fd, "%s: request chunk, timeo=%lu\n",
					inet_ntoa(ptr->srcip), ptr->args[0]);
				break;
			case EV_CLIREQRA:
				fprintf(fd, "%s: issue readahead, "
					"empty=%lu, filling=%lu\n",
					inet_ntoa(ptr->srcip),
					ptr->args[0], ptr->args[1]);
				break;
			case EV_CLIJOINREQ:
				fprintf(fd, "%s: send JOIN, ID=%lx\n",
					inet_ntoa(ptr->srcip), ptr->args[0]);
				break;
			case EV_CLIJOINREP:
				fprintf(fd, "%s: got JOIN reply, blocks=%lu\n",
					inet_ntoa(ptr->srcip), ptr->args[0]);
				break;
			case EV_CLILEAVE:
			{
				unsigned long long bytes;
				bytes = (unsigned long long)ptr->args[2] << 32;
				bytes |= ptr->args[3];
				fprintf(fd, "%s: send LEAVE, ID=%lx, "
					"time=%lu, bytes=%qu\n",
					inet_ntoa(ptr->srcip),
					ptr->args[0], ptr->args[1], bytes);
				break;
			}
			case EV_CLISTAMP:
				fprintf(fd, "%s: update chunk %lu, stamp %lu.%06lu\n",
					inet_ntoa(ptr->srcip), ptr->args[0],
					ptr->args[1], ptr->args[2]);
				break;
			case EV_CLIDCSTART:
				fprintf(fd, "%s: decompressing chunk %lu, "
					"idle=%lu, (dblock=%lu, widle=%lu)\n",
					inet_ntoa(ptr->srcip),
					ptr->args[0], ptr->args[1],
					ptr->args[2], ptr->args[3]);
				break;
			case EV_CLIDCDONE:
				fprintf(fd, "%s: chunk %lu decompressed, "
					"%lu left, (dblock=%lu, widle=%lu)\n",
					inet_ntoa(ptr->srcip),
					ptr->args[0], ptr->args[1],
					ptr->args[2], ptr->args[3]);
				break;
			case EV_CLIDCIDLE:
				fprintf(fd, "%s: decompressor IDLE\n",
					inet_ntoa(ptr->srcip));
				break;
			case EV_CLIWRSTATUS:
				fprintf(fd, "%s: writer %s\n",
					inet_ntoa(ptr->srcip),
					ptr->args[0] ? "IDLE" : "STARTED");
				break;
			case EV_CLIGOTPKT:
				stamp.tv_sec = ptr->args[0];
				stamp.tv_usec = ptr->args[1];
				timersub(&ptr->tstamp, &stamp, &stamp);
				fprintf(fd, "%s: got block, wait=%03ld.%03ld\n",
					inet_ntoa(ptr->srcip),
					stamp.tv_sec, stamp.tv_usec/1000);
				break;
			case EV_CLIRTIMO:
				stamp.tv_sec = ptr->args[0];
				stamp.tv_usec = ptr->args[1];
				timersub(&ptr->tstamp, &stamp, &stamp);
				fprintf(fd, "%s: recv timeout, wait=%03ld.%03ld\n",
					inet_ntoa(ptr->srcip),
					stamp.tv_sec, stamp.tv_usec/1000);
				break;
			}
		}
		if (++ptr == evend)
			ptr = eventlog;
	} while (ptr != evptr);
	fflush(fd);
	evlogging = oevlogging;
}
#endif
