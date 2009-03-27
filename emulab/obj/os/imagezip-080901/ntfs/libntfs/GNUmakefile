#
# Copyright (c) 2000-2005 University of Utah and the Flux Group.
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
SRCDIR		= ../../../../../os/imagezip/ntfs/libntfs
TESTBED_SRCDIR	= ../../../../..
OBJDIR		= ../../../..
SUBDIR		= os/imagezip/ntfs/libntfs
NTFSVER		= ntfsprogs-1.7.1
NTFSDIR		= ntfsprogs
LIBSRCDIR	= $(NTFSDIR)/libntfs
LOCALPKGHOST	= 
PKGHOST		= www.emulab.net

include $(OBJDIR)/Makeconf

ifndef HAVE_GCC3
CC		= gcc30
endif
ifdef LINUX
INCLUDES        = -I${NTFSDIR}/include -I${OBJDIR}
FETCH		= wget -q -N
PATCH		= patch -sN -d $(NTFSVER) -p1
else
INCLUDES        = -nostdinc -I${NTFSDIR}/include -I${OBJDIR} \
                  -I${SRCDIR}/../extra_bsd_includes \
                  -I/usr/include \
                  -I/usr/local/include
FETCH		= fetch -m
PATCH		= patch -sN
endif
UNPACK		= tar zxf
MV		= mv -f
ifndef HAVE_LOCALE
INCLUDES        += -I${SRCDIR}/../liblocale/include
endif

all:	libntfs.a

include $(TESTBED_SRCDIR)/GNUmakerules

CFLAGS	        = -O2 -g -static -Wall $(INCLUDES)

OBJS=	attrib.o \
	bitmap.o \
	bootsect.o \
	compat.o \
	debug.o \
	dir.o \
	disk_io.o \
	inode.o \
	lcnalloc.o \
	mft.o \
	mst.o \
	runlist.o \
	unistr.o \
	volume.o

SRCS=	$(patsubst %.o,$(LIBSRCDIR)/%.c,$(OBJS))

%.o:	$(LIBSRCDIR)/%.c
	$(CC) $(CFLAGS) -c -o $@ $<

libntfs.a: $(LIBSRCDIR)/patched $(OBJS)
	$(AR) crv $@ $(OBJS)
	$(RANLIB) $@

$(SRCS): $(LIBSRCDIR)/patched

$(LIBSRCDIR)/patched:
	@if [ ! -e "$(NTFSVER).tar.gz" ]; then \
	    if [ -n "$(LOCALPKGHOST)" ]; then \
	        if [ `$(FETCH) http://$(LOCALPKGHOST)/downloads/$(NTFSVER).tar.gz` ]; then \
		    $(FETCH) http://$(PKGHOST)/downloads/$(NTFSVER).tar.gz; \
	        fi \
	    else \
		$(FETCH) http://$(PKGHOST)/downloads/$(NTFSVER).tar.gz; \
	    fi \
	fi
	$(UNPACK) $(NTFSVER).tar.gz
ifdef LINUX
	$(PATCH) < $(SRCDIR)/ntfs.linuxpatch
else
	$(PATCH) < $(SRCDIR)/ntfs.patch
endif
	$(MV) $(NTFSVER) $(NTFSDIR)
	$(NTFSDIR)/configure
	$(MV) config.h $(NTFSDIR)/include
	touch $(LIBSRCDIR)/patched

clean:
	-rm -f *.o *~ *.a config.* Makefile
	-rm -rf $(NTFSDIR) 

distclean:
	-rm -rf *.gz *.spec *-h doc libtool include libntfs
