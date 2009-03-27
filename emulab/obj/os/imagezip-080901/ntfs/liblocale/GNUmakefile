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

SRCDIR		= ../../../../../os/imagezip/ntfs/liblocale
TESTBED_SRCDIR	= ../../../../..
OBJDIR		= ../../../..
SUBDIR		= os/imagezip/ntfs/liblocale

include $(OBJDIR)/Makeconf

all:	liblocale.a

include $(TESTBED_SRCDIR)/GNUmakerules

CC		= gcc
CFLAGS	       += -O2 -g -static -Wall -I${OBJDIR} -I/usr/local/include \
			-I${SRCDIR}/include

OBJS=	big5.o btowc.o collate.o collcmp.o euc.o fix_grouping.o frune.o \
	isctype.o iswctype.o \
	ldpart.o lmessages.o lmonetary.o lnumeric.o localeconv.o mblen.o \
	mbrlen.o \
	mbrtowc.o mbrune.o mbsinit.o mbsrtowcs.o mbtowc.o mbstowcs.o \
	mskanji.o nl_langinfo.o nomacros.o none.o rune.o \
	runetype.o setinvalidrune.o setlocale.o setrunelocale.o table.o \
	tolower.o toupper.o utf2.o utf8.o wcrtomb.o wcsrtombs.o wcsftime.o \
	wcstod.o \
	wcstoimax.o wcstol.o wcstoll.o \
	wcstombs.o \
	wcstoul.o wcstoull.o wcstoumax.o wctob.o wctomb.o wctrans.o wctype.o \
	wcwidth.o

liblocale.a: $(OBJS)
	$(AR) crv $@ $(OBJS)
	$(RANLIB) $@

clean:
	-rm -f *.o *~ *.a 
