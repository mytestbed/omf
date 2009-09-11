#
# Copyright (c) 2000-2004 University of Utah and the Flux Group.
# All rights reserved.
# 
# This file is part of Frisbee, which is part of the Netbed/Emulab Network
# Testbed.  Frisbee is free software, also known as "open source;" you can
# redistribute it and/or modify it under the terms of the GNU General
# Public License (GPL), version 2, as published by the Free Software
# Foundation (FSF).  To explore alternate licensing terms, contact the
# University of Utah at flux-dist@cs.utah.edu or +1-801-585-3271.
# 
# Frisbee is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
# FITNESS FOR A PARTICULAR PURPOSE.  See the GPL for more details.  You
# should have received a copy of the GPL along with Frisbee; see the file
# COPYING.  If not, write to the FSF, 59 Temple Place #330, Boston, MA
# 02111-1307, USA, or look at http://www.fsf.org/copyleft/gpl.html .
#

# 
# Makefile for the standalone version of frisbee.
# (Standalone meaning not part of the Netbed build environment.)
#
SBINDIR=$(DESTDIR)/usr/sbin
BINDIR=$(SBINDIR)	

IMAGEZIPDIR	= ../imagezip

SHAREDOBJS	= log.o network.o trace.o utils.o

PTHREADCFLAGS	= -D_THREAD_SAFE -pthread

# get 64-bit off_t and pread/pwrite protos
LINUXOPTS	= -D_FILE_OFFSET_BITS=64 -D_GNU_SOURCE \
		  -D_XOPEN_SOURCE=500 -D_BSD_SOURCE=1

CLIENTFLAGS	= $(CFLAGS)
CLIENTLIBS	= -lz $(PTHREADLIBS)
CLIENTOBJS	= client.o frisbee.o $(SHAREDOBJS)

SERVERFLAGS	= $(CFLAGS)
SERVERLIBS	= $(PTHREADLIBS)
SERVEROBJS	= server.o $(SHAREDOBJS)

CFLAGS		= -O2 -g -Wall -fno-builtin-log -static \
		  $(PTHREADCFLAGS) $(LINUXOPTS) -DSTATS
LDFLAGS		= -static

#
# Define this if your implementation of cond_vars works well
# ("works well" in this case means doesn't hang forever or burn up
# the CPU while in condwait).
#
CFLAGS		+= -DCONDVARS_WORK

VERSION = shell grep -o -E '[0-9]+\.[0-9.-]+' -m 1 $(FSRC)/debian/changelog

all: frisbee frisbeed

version:
	cd debian/ && sed -e "s,@VERSION@,$(VERSION),g" files.tmp > files

frisbee: $(CLIENTOBJS)
	$(CC) $(LDFLAGS) $(CLIENTFLAGS) $(CLIENTOBJS) $(CLIENTLIBS) -o frisbee
	cp frisbee frisbee.debug
	strip frisbee

frisbeed: $(SERVEROBJS)
	$(CC) $(LDFLAGS) $(SERVERFLAGS) $(SERVEROBJS) $(SERVERLIBS) -o frisbeed
	cp frisbeed frisbeed.debug
	strip frisbeed


event.o:	$(SRCDIR)/event.c decls.h log.h event.h
	$(CC) $(EVENTFLAGS) -c event.c

$(IMAGEZIPDIR)/imageunzip.c: $(IMAGEZIPDIR)/imagehdr.h $(IMAGEZIPDIR)/queue.h

frisbee.o:	$(IMAGEZIPDIR)/imageunzip.c
	$(CC) -c $(CFLAGS) -DFRISBEE -I$(IMAGEZIPDIR) -o frisbee.o \
		$(IMAGEZIPDIR)/imageunzip.c

client.o:	decls.h log.h utils.h trace.h
server.o:	decls.h log.h utils.h trace.h
log.o:		decls.h log.h
network.o:	decls.h utils.h
trace.o:	decls.h trace.h log.h

apt:  version all
	dpkg-buildpackage -rfakeroot

install:
	install -d $(BINDIR) 
	install -m 744 ./frisbeed $(BINDIR)
	install -m 744 ./frisbee $(BINDIR)

clean:
	rm -f *.o *.a frisbee frisbeed frisbee.debug frisbeed.debug
	rm -rf debian/frisbee
