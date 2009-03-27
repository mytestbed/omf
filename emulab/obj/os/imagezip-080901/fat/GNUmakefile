#
# Copyright (c) 2000-2003 University of Utah and the Flux Group.
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

SRCDIR		= ../../../../os/imagezip/fat
TESTBED_SRCDIR	= ../../../..
OBJDIR		= ../../..
SUBDIR		= os/imagezip/fat
MAINDIR		= $(SRCDIR)/..

include $(OBJDIR)/Makeconf

CFLAGS		+= $(SUBDIRCFLAGS) -I$(MAINDIR) -I$(SRCDIR)

all:	libfat.a

include $(TESTBED_SRCDIR)/GNUmakerules

OBJS = fat_glue.o fat_boot.o fat_fat.o

fat_glue.o: fat_glue.h $(MAINDIR)/sliceinfo.h $(MAINDIR)/global.h

libfat.a:	$(OBJS)
	$(AR) $(ARFLAGS) $@ $?
	$(RANLIB) $@

install: 

clean:
	rm -f libfat.a $(OBJS)
