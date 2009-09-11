/*
 * Copyright (c) 2000-2004 University of Utah and the Flux Group.
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
 * Network routines.
 */
#include <sys/types.h>
#include <sys/socket.h>
#include <sys/time.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <netdb.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <signal.h>
#include <errno.h>
#include "decls.h"
#include "utils.h"

#ifdef STATS
unsigned long nonetbufs;
#define DOSTAT(x)	(x)
#else
#define DOSTAT(x)
#endif

/* Max number of times to attempt bind to port before failing. */
#define MAXBINDATTEMPTS		10

/* Max number of hops multicast hops. */
#define MCAST_TTL		5

static int		sock;
struct in_addr		myipaddr;
static int		nobufdelay = -1;
int			broadcast = 0;

static void
CommonInit(void)
{
	struct sockaddr_in	name;
	struct timeval		timeout;
	int			i;
	char			buf[BUFSIZ];
	struct hostent		*he;
	
	if ((sock = socket(PF_INET, SOCK_DGRAM, IPPROTO_UDP)) < 0)
		pfatal("Could not allocate a socket");

	i = SOCKBUFSIZE;
	if (setsockopt(sock, SOL_SOCKET, SO_SNDBUF, &i, sizeof(i)) < 0)
		pwarning("Could not increase send socket buffer size to %d",
			 SOCKBUFSIZE);
    
	i = SOCKBUFSIZE;
	if (setsockopt(sock, SOL_SOCKET, SO_RCVBUF, &i, sizeof(i)) < 0)
		pwarning("Could not increase recv socket buffer size to %d",
			 SOCKBUFSIZE);

	name.sin_family      = AF_INET;
	name.sin_port	     = htons(portnum);
	name.sin_addr.s_addr = htonl(INADDR_ANY);

	i = MAXBINDATTEMPTS;
	while (i) {
		if (bind(sock, (struct sockaddr *)&name, sizeof(name)) == 0)
			break;

		if (--i == 0)
			pfatal("Could not bind to port %d!", portnum);

		pwarning("Bind to port %d failed. Will try %d more times!",
			 portnum, i);
		sleep(5);
	}
	log("Bound to port %d", portnum);

	/*
	 * At present, we use a multicast address in both directions.
	 */
	if ((ntohl(mcastaddr.s_addr) >> 28) == 14) {
		unsigned int loop = 0, ttl = MCAST_TTL;
		struct ip_mreq mreq;

		log("Using Multicast");

		mreq.imr_multiaddr.s_addr = mcastaddr.s_addr;

		if (mcastif.s_addr)
			mreq.imr_interface.s_addr = mcastif.s_addr;
		else
			mreq.imr_interface.s_addr = htonl(INADDR_ANY);

		if (setsockopt(sock, IPPROTO_IP, IP_ADD_MEMBERSHIP,
			       &mreq, sizeof(mreq)) < 0)
			pfatal("setsockopt(IPPROTO_IP, IP_ADD_MEMBERSHIP)");

		if (setsockopt(sock, IPPROTO_IP, IP_MULTICAST_TTL,
			       &ttl, sizeof(ttl)) < 0) 
			pfatal("setsockopt(IPPROTO_IP, IP_MULTICAST_TTL)");

		/* Disable local echo */
		if (setsockopt(sock, IPPROTO_IP, IP_MULTICAST_LOOP,
			       &loop, sizeof(loop)) < 0)
			pfatal("setsockopt(IPPROTO_IP, IP_MULTICAST_LOOP)");

		if (mcastif.s_addr &&
		    setsockopt(sock, IPPROTO_IP, IP_MULTICAST_IF,
			       &mcastif, sizeof(mcastif)) < 0) {
			pfatal("setsockopt(IPPROTO_IP, IP_MULTICAST_IF)");
		}
	}
	else if (broadcast) {
		/*
		 * Otherwise, we use a broadcast addr. 
		 */
		i = 1;

		log("Setting broadcast mode\n");
		
		if (setsockopt(sock, SOL_SOCKET, SO_BROADCAST,
			       &i, sizeof(i)) < 0)
			pfatal("setsockopt(SOL_SOCKET, SO_BROADCAST)");
	}

	/*
	 * We use a socket level timeout instead of polling for data.
	 */
	timeout.tv_sec  = 0;
	timeout.tv_usec = PKTRCV_TIMEOUT;
	
	if (setsockopt(sock, SOL_SOCKET, SO_RCVTIMEO,
		       &timeout, sizeof(timeout)) < 0)
		pfatal("setsockopt(SOL_SOCKET, SO_RCVTIMEO)");

	/*
	 * If a specific interface IP is specified, use that to
	 * tag our outgoing packets.  Otherwise we use the IP address
	 * associated with our hostname.
	 */
	if (mcastif.s_addr)
		myipaddr.s_addr = mcastif.s_addr;
	else {
		if (gethostname(buf, sizeof(buf)) < 0)
			pfatal("gethostname failed");

		if ((he = gethostbyname(buf)) == 0)
			fatal("gethostbyname: %s", hstrerror(h_errno));

		memcpy((char *)&myipaddr, he->h_addr, sizeof(myipaddr));
	}

	/*
	 * Compute the out of buffer space delay.
	 */
	if (nobufdelay < 0)
		nobufdelay = sleeptime(100, NULL, 1);
}

int
ClientNetInit(void)
{
	CommonInit();
	
	return 1;
}

unsigned long
ClientNetID(void)
{
	return ntohl(myipaddr.s_addr);
}

int
ServerNetInit(void)
{
	CommonInit();

	return 1;
}

/*
 * Look for a packet on the socket. Propogate the errors back to the caller
 * exactly as the system call does. Remember that we set up a socket timeout
 * above, so we will get EWOULDBLOCK errors when no data is available. 
 *
 * The amount of data received is determined from the datalen of the hdr.
 * All packets are actually the same size/structure. 
 *
 * Returns 0 for a good packet, 1 for a back packet, -1 on timeout.
 */
int
PacketReceive(Packet_t *p)
{
	struct sockaddr_in from;
	int		   mlen, alen;

	alen = sizeof(from);
	bzero(&from, alen);
	if ((mlen = recvfrom(sock, p, sizeof(*p), 0,
			     (struct sockaddr *)&from, &alen)) < 0) {
		if (errno == EWOULDBLOCK)
			return -1;
		pfatal("PacketReceive(recvfrom)");
	}

	/*
	 * Basic integrity checks
	 */
	if (mlen < sizeof(p->hdr) + p->hdr.datalen) {
		log("Bad message length (%d != %d)",
		    mlen, p->hdr.datalen);
		return 1;
	}
	if (p->hdr.srcip != from.sin_addr.s_addr) {
		log("Bad message source (%x != %x)",
		    ntohl(from.sin_addr.s_addr), ntohl(p->hdr.srcip));
		return 1;
	}

	return 0;
}

/*
 * We use blocking sends since there is no point in giving up. All packets
 * go to the same place, whether client or server.
 *
 * The amount of data sent is determined from the datalen of the packet hdr.
 * All packets are actually the same size/structure. 
 */
void
PacketSend(Packet_t *p, int *resends)
{
	struct sockaddr_in to;
	int		   len, delays;

	len = sizeof(p->hdr) + p->hdr.datalen;
	p->hdr.srcip = myipaddr.s_addr;

	to.sin_family      = AF_INET;
	to.sin_port        = htons(portnum);
	to.sin_addr.s_addr = mcastaddr.s_addr;

	delays = 0;
	while (sendto(sock, (void *)p, len, 0, 
		      (struct sockaddr *)&to, sizeof(to)) < 0) {
		if (errno != ENOBUFS)
			pfatal("PacketSend(sendto)");

		/*
		 * ENOBUFS means we ran out of mbufs. Okay to sleep a bit
		 * to let things drain.
		 */
		delays++;
		fsleep(nobufdelay);
	}

	DOSTAT(nonetbufs += delays);
	if (resends != 0)
		*resends = delays;
}

/*
 * Basically the same as above, but instead of sending to the multicast
 * group, send to the (unicast) IP in the packet header. This simplifies
 * the logic in a number of places, by avoiding having to deal with
 * multicast packets that are not destined for us, but for someone else.
 */
void
PacketReply(Packet_t *p)
{
	struct sockaddr_in to;
	int		   len;

	len = sizeof(p->hdr) + p->hdr.datalen;

	to.sin_family      = AF_INET;
	to.sin_port        = htons(portnum);
	to.sin_addr.s_addr = p->hdr.srcip;
	p->hdr.srcip       = myipaddr.s_addr;

	while (sendto(sock, (void *)p, len, 0, 
		      (struct sockaddr *)&to, sizeof(to)) < 0) {
		if (errno != ENOBUFS)
			pfatal("PacketSend(sendto)");

		/*
		 * ENOBUFS means we ran out of mbufs. Okay to sleep a bit
		 * to let things drain.
		 */
		DOSTAT(nonetbufs++);
		fsleep(nobufdelay);
	}
}

int
PacketValid(Packet_t *p, int nchunks)
{
	switch (p->hdr.type) {
	case PKTTYPE_REQUEST:
	case PKTTYPE_REPLY:
		break;
	default:
		return 0;
	}

	switch (p->hdr.subtype) {
	case PKTSUBTYPE_BLOCK:
		if (p->hdr.datalen < sizeof(p->msg.block))
			return 0;
		if (p->msg.block.chunk < 0 ||
		    p->msg.block.chunk >= nchunks ||
		    p->msg.block.block < 0 ||
		    p->msg.block.block >= CHUNKSIZE)
			return 0;
		break;
	case PKTSUBTYPE_REQUEST:
		if (p->hdr.datalen < sizeof(p->msg.request))
			return 0;
		if (p->msg.request.chunk < 0 ||
		    p->msg.request.chunk >= nchunks ||
		    p->msg.request.block < 0 ||
		    p->msg.request.block >= CHUNKSIZE ||
		    p->msg.request.count < 0 ||
		    p->msg.request.block+p->msg.request.count > CHUNKSIZE)
			return 0;
		break;
	case PKTSUBTYPE_PREQUEST:
		if (p->hdr.datalen < sizeof(p->msg.prequest))
			return 0;
		if (p->msg.prequest.chunk < 0 ||
		    p->msg.prequest.chunk >= nchunks)
			return 0;
		break;
	case PKTSUBTYPE_JOIN:
		if (p->hdr.datalen < sizeof(p->msg.join))
			return 0;
		break;
	case PKTSUBTYPE_LEAVE:
		if (p->hdr.datalen < sizeof(p->msg.leave))
			return 0;
		break;
	case PKTSUBTYPE_LEAVE2:
		if (p->hdr.datalen < sizeof(p->msg.leave2))
			return 0;
		break;
	default:
		return 0;
	}

	return 1;
}
