#
# Copyright (c) 2000-2004 University of Utah and the Flux Group.
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

SRCDIR		= ../../../../os/imagezip/ntfs
TESTBED_SRCDIR	= ../../../..
OBJDIR		= ../../..
SUBDIR		= os/imagezip/ntfs
MAINDIR		= $(SRCDIR)/..

include $(OBJDIR)/Makeconf

LIBS		= libntfs.a
ifndef HAVE_LOCALE
LIBS		+= liblocale.a
endif

ifndef HAVE_GCC3
CC		= gcc30
endif
CFLAGS		+= $(SUBDIRCFLAGS) -I$(MAINDIR) -Ilibntfs/ntfsprogs/include
ifndef LINUX
CFLAGS		+= -I$(SRCDIR)/extra_bsd_includes \
		   -I$(SRCDIR)/liblocale/include
endif

all:	$(LIBS)

include $(TESTBED_SRCDIR)/GNUmakerules

ntfs_glue.o: $(MAINDIR)/global.h $(MAINDIR)/sliceinfo.h

libntfs.a: libntfs/libntfs.a ntfs_glue.o
	cp libntfs/libntfs.a libntfs.a
	$(AR) $(ARFLAGS) $@ ntfs_glue.o
	$(RANLIB) $@

liblocale.a: liblocale/liblocale.a
	cp -p liblocale/liblocale.a liblocale.a

libntfs/libntfs.a:
	@$(MAKE) -C libntfs

liblocale/liblocale.a:
	@$(MAKE) -C liblocale

clean:
	@$(MAKE) -C libntfs clean
	@$(MAKE) -C liblocale clean
	/bin/rm -f libntfs.a liblocale.a ntfs_glue.o

distclean:
	@$(MAKE) -C libntfs distclean
