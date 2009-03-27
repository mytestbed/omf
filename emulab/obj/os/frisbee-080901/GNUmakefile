#
# Copyright (c) 2000-2004, 2006, 2007 University of Utah and the Flux Group.
# All rights reserved.
# This file is part of the Emulab network testbed software.
# 
# Emulab is free software, also known as "open source;" you can
# redistribute it and/or modify it under the terms of the GNU Affero
# General Public License as published by the Free Software Foundation,
# either version 3 of the License, or (at your option) any later version.
# 
# Emulab is distributed in the hope that it will be useful, but WITHOUT ANY
# WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE.  See the GNU Affero General Public License for
# more details, which can be found in the file AGPL-COPYING at the root of
# the source tree.
# 
# You should have received a copy of the GNU Affero General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#

SRCDIR		= ../../../os/frisbee.redux
TESTBED_SRCDIR	= ../../..
OBJDIR		= ../..
SUBDIR		= os/frisbee.redux

DISTFILES	= TODO client.c decls.h event.c event.h log.c log.h \
		  network.c queue.h server.c trace.c trace.h utils.c utils.h
EXPANDCOPYRIGHT	= /usr/site/lib/copyright/expand-copyr

SYSTEM	:= $(shell uname -s)
ifeq ($(SYSTEM),FreeBSD)
FBSDREL	:= $(shell uname -r | sed -e 's/\([^-][^-]*\)-.*/\1/')
# XXX 5.3 and linuxthreads don't see to get along
ifeq ($(FBSDREL),5.3)
WITH_LTHREADS	= 0
else
WITH_LTHREADS	= 1
endif
endif

include $(OBJDIR)/Makeconf

all:	frisbee frisbeed

include $(TESTBED_SRCDIR)/GNUmakerules

FRISBEEDIR	= $(OBJDIR)/os/imagezip

SHAREDOBJS	= log.o network.o trace.o utils.o

ifeq ($(SYSTEM),Linux)
PTHREADCFLAGS	+= -D_FILE_OFFSET_BITS=64 -D_GNU_SOURCE -D_THREAD_SAFE -pthread
else
ifeq ($(WITH_LTHREADS),1)
PTHREADCFLAGS	= -D_THREAD_SAFE -I/usr/local/include/pthread/linuxthreads
PTHREADLIBS	= -L/usr/local/lib -llthread -llgcc_r
else
PTHREADCFLAGS	= -DCONDVARS_WORK
PTHREADLIBS	= -lpthread
endif
endif

CLIENTFLAGS	= $(CFLAGS)
CLIENTLIBS	= -lz $(PTHREADLIBS)
CLIENTOBJS	= client.o frisbee.o disksize.o $(SHAREDOBJS)

SERVERFLAGS	= $(CFLAGS)
SERVERLIBS	= $(PTHREADLIBS)
SERVEROBJS	= server.o $(SHAREDOBJS)

CFLAGS		= -O2 -g -Wall -fno-builtin-log $(LDSTATIC) $(PTHREADCFLAGS) -DSTATS
LDFLAGS		= $(LDSTATIC)

#
# Define this if your implementation of cond_vars works well
# ("works well" in this case means doesn't hang forever or burn up
# the CPU while in condwait).
#
#CFLAGS		+= -DCONDVARS_WORK

# Define this to a non-zero value to enable recording of trace data
#CFLAGS		+= -DNEVENTS=50000

# Turn on client event handling
#CFLAGS		+= -DDOEVENTS
#CLIENTOBJS	+= event.o $(OBJDIR)/event/lib/event.o $(OBJDIR)/event/lib/util.o
#CLIENTLIBS	+= `elvin-config --libs vin4c`
#EVENTFLAGS	= $(CFLAGS) `elvin-config --cflags vin4c` -I$(TESTBED_SRCDIR)

frisbee: $(CLIENTOBJS)
	$(CC) $(LDFLAGS) $(CLIENTFLAGS) $(CLIENTOBJS) $(CLIENTLIBS) -o frisbee
	cp frisbee frisbee.debug
	strip frisbee

frisbeed: $(SERVEROBJS)
	$(CC) $(LDFLAGS) $(SERVERFLAGS) $(SERVEROBJS) $(SERVERLIBS) -o frisbeed
	cp frisbeed frisbeed.debug
	strip frisbeed


log.o:		$(SRCDIR)/log.c decls.h log.h
	$(CC) $(CFLAGS) -DLOG_TESTBED=$(LOG_TESTBED) -c $(SRCDIR)/log.c

event.o:	$(SRCDIR)/event.c decls.h log.h event.h
	$(CC) $(EVENTFLAGS) -c $(SRCDIR)/event.c

$(FRISBEEDIR)/imageunzip.c: $(FRISBEEDIR)/imagehdr.h $(FRISBEEDIR)/queue.h

disksize.o:	$(FRISBEEDIR)/disksize.c
	$(CC) -c $(CFLAGS) -I$(FRISBEEDIR) -o disksize.o $<

frisbee.o:	$(FRISBEEDIR)/imageunzip.c
	$(CC) -c $(CFLAGS) -DFRISBEE -I$(FRISBEEDIR) -o frisbee.o $<

client.o:	decls.h log.h utils.h trace.h
server.o:	decls.h log.h utils.h trace.h
log.o:		decls.h log.h
network.o:	decls.h utils.h
trace.o:	decls.h trace.h log.h

install:	$(INSTALL_SBINDIR)/frisbeed $(INSTALL_SBINDIR)/frisbee

client: frisbee

client-install: client
	$(INSTALL_PROGRAM) frisbee $(DESTDIR)$(CLIENT_BINDIR)

clean:
	/bin/rm -f *.o *.a frisbee frisbeed frisbee.debug frisbeed.debug
	/bin/rm -f frisbee.tar frisbee.tar.gz
	/bin/rm -rf frisbee-dist

frisbee.tar.gz: frisbee.tar
	gzip -c frisbee.tar > frisbee.tar.gz

frisbee.tar: frisbee-dist
	tar cf frisbee.tar frisbee-dist
	rm -rf frisbee-dist

frisbee-dist: Makefile.sa Makefile-linux.sa README.sa $(DISTFILES)
	rm -rf frisbee-dist
	mkdir frisbee-dist frisbee-dist/frisbee frisbee-dist/doc
	(cd $(SRCDIR); \
		tar cf - Makefile.sa Makefile-linux.sa README.sa $(DISTFILES))|\
			(cd frisbee-dist/frisbee; tar xf -)
	mv frisbee-dist/frisbee/Makefile.sa frisbee-dist/frisbee/Makefile
	mv frisbee-dist/frisbee/Makefile-linux.sa frisbee-dist/frisbee/Makefile-linux
	mv frisbee-dist/frisbee/README.sa frisbee-dist/README
	cp $(TESTBED_SRCDIR)/GPL-COPYING frisbee-dist/COPYING
	cp $(TESTBED_SRCDIR)/doc/papers/frisbee-usenix03.pdf frisbee-dist/doc
	(cd frisbee-dist/frisbee; \
		$(EXPANDCOPYRIGHT) Makefile Makefile-linux $(DISTFILES))
	(cd ../imagezip; $(MAKE) imagezip.tar)
	(cd frisbee-dist; tar xf -; mv imagezip-dist imagezip) \
		< ../imagezip/imagezip.tar
