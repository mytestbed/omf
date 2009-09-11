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
# Makefile for the standalone version of imagezip/unzip.
# (Standalone meaning not part of the Netbed build environment.)
#
BINDIR=	$(DESTDIR)/usr/bin
INSTALL=/usr/bin/install
#
# Which filesystems to support
#
WITH_EXTFS	= 1
WITH_FFS	= 1
WITH_FAT	= 0
WITH_NTFS	= 0	# needs work

PTHREADCFLAGS	= -D_THREAD_SAFE -pthread
#PTHREADLIBS	= -L/usr/local/lib -llgcc_r

# get 64-bit off_t and pread/pwrite protos
LINUXOPTS	= -D_FILE_OFFSET_BITS=64 -D_GNU_SOURCE \
		  -D_XOPEN_SOURCE=500 -D_BSD_SOURCE=1

CFLAGS		= -Wall -O2 -g -static -I. $(PTHREADCFLAGS) $(LINUXOPTS)
LIBS 		= -lz $(PTHREADLIBS)
UNZIPCFLAGS	= $(CFLAGS) -Wall
UNZIPLIBS	= $(LIBS)

ifdef WITH_EXTFS
FSOBJS		+= extfs/extfs.o extfs/reloc_lilo.o
CFLAGS		+= -DWITH_EXTFS -Iextfs
endif

ifdef WITH_FFS
FSOBJS		+= ffs/ffs.o
CFLAGS		+= -DWITH_FFS -Iffs
endif

ifdef WITH_FAT
FSOBJS		+= fat/fat_fat.o fat/fat_boot.o fat/fat_glue.o
CFLAGS		+= -DWITH_FAT -Ifat
endif

VERSION = shell grep -o -E '[0-9]+\.[0-9.-]+' -m 1 $(FSRC)/debian/changelog

all:	imagezip imageunzip imagedump

imagezip: imagezip.o version.o $(FSOBJS)
	$(CC) $(CFLAGS) imagezip.o version.o $(FSOBJS) $(LIBS) -o imagezip

imageunzip: imageunzip.o crc.o version.o
	$(CC) $(CFLAGS) imageunzip.o crc.o version.o $(UNZIPLIBS) -o imageunzip

imageunzip.o:	imageunzip.c
	$(CC) -c $(UNZIPCFLAGS) -o imageunzip.o $<

imagedump: imagedump.o version.o
	$(CC) $(CFLAGS) imagedump.o version.o $(LIBS) -o imagedump

version.c: imagezip.c imageunzip.c imagedump.c
	echo >$@ "char build_info[] = \"Built `date +%d-%b-%Y` by `id -nu`@`hostname | sed 's/\..*//'`:`pwd`\";"

version:
	cd debian/ && sed -e "s,@VERSION@,$(VERSION),g" files.tmp > files

install:
	$(INSTALL) -d $(BINDIR)
	$(INSTALL) -m 0744 imagezip $(BINDIR)/imagezip
	$(INSTALL) -m 0744 imageunzip $(BINDIR)/imageunzip
	$(INSTALL) -m 0744 imagedump $(BINDIR)/imagedump

apt:  version all
	dpkg-buildpackage -rfakeroot

clean:
	rm -f *.o imagezip imageunzip imagedump version.c
	rm -rf debian/imagezip
