# Generated automatically from Makefile.in by configure.
# Makefile.in generated automatically by automake 1.4-p5 from Makefile.am

# Copyright (C) 1994, 1995-8, 1999, 2001 Free Software Foundation, Inc.
# This Makefile.in is free software; the Free Software Foundation
# gives unlimited permission to copy and/or distribute it,
# with or without modifications, as long as this notice is preserved.

# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY, to the extent permitted by law; without
# even the implied warranty of MERCHANTABILITY or FITNESS FOR A
# PARTICULAR PURPOSE.

#
# Before making a release, the LTVERSION string should be modified.
# The string is of the form CURRENT:REVISION:AGE.
#
# CURRENT (C)
#	The most recent interface number that this library implements.
#
# REVISION (R)
#	The implementation number that this library implements.
#
# AGE (A)
#	The difference between the newest and oldest interfaces that this
#	library implements. In other works, the library implements all the
#	interface numbers in the range from number 'CURRENT - AGE' to
#	'CURRENT'.
#
# This means that:
#
#   - If interfaces have been changed or added, but binary compatibility has
#     been preserved, change to C+1:0:A+1
#
#   - If binary compatibility has been broken (eg removed or changed
#     interfaces) change to C+1:0:0
#
#   - If the interface is the same as the previous version, change to C:R+1:A
#


SHELL = /bin/sh

srcdir = ../ntfsprogs/libntfs
top_srcdir = ../ntfsprogs
VPATH = ../ntfsprogs/libntfs
prefix = /usr/local
exec_prefix = ${prefix}

bindir = ${exec_prefix}/bin
sbindir = ${exec_prefix}/sbin
libexecdir = ${exec_prefix}/libexec
datadir = ${prefix}/share
sysconfdir = ${prefix}/etc
sharedstatedir = ${prefix}/com
localstatedir = ${prefix}/var
libdir = ${exec_prefix}/lib
infodir = ${prefix}/info
mandir = ${prefix}/man
includedir = ${prefix}/include
oldincludedir = /usr/include

DESTDIR =

pkgdatadir = $(datadir)/ntfsprogs
pkglibdir = $(libdir)/ntfsprogs
pkgincludedir = $(includedir)/ntfsprogs

top_builddir = ..

ACLOCAL = /home/cdw/omf/trunk/emulab/obj/os/imagezip-080901/ntfs/libntfs/ntfsprogs/missing aclocal
AUTOCONF = autoconf
AUTOMAKE = /home/cdw/omf/trunk/emulab/obj/os/imagezip-080901/ntfs/libntfs/ntfsprogs/missing automake
AUTOHEADER = autoheader

INSTALL = /usr/bin/install -c
INSTALL_PROGRAM = ${INSTALL} $(AM_INSTALL_PROGRAM_FLAGS)
INSTALL_DATA = ${INSTALL} -m 644
INSTALL_SCRIPT = ${INSTALL_PROGRAM}
transform = s,x,x,

NORMAL_INSTALL = :
PRE_INSTALL = :
POST_INSTALL = :
NORMAL_UNINSTALL = :
PRE_UNINSTALL = :
POST_UNINSTALL = :
build_alias = i686-pc-linux-gnu
build_triplet = i686-pc-linux-gnu
host_alias = i686-pc-linux-gnu
host_triplet = i686-pc-linux-gnu
target_alias = i686-pc-linux-gnu
target_triplet = i686-pc-linux-gnu
AS = @AS@
AUTODIRS = 
CC = gcc-3.4
CFLAGS = -O2 -g -static -Wall -Intfsprogs/include -I../../../..
CPPFLAGS = -I/usr/local/include -I/usr/include/python2.5
CXX = g++
DLLTOOL = @DLLTOOL@
ECHO = /bin/echo
EXEEXT = 
LDFLAGS = 
LIBTOOL = $(SHELL) $(top_builddir)/libtool
LIBTOOL_DEPS = ntfsprogs/ltmain.sh
LN_S = ln -s
MAINT = #
MAKEINFO = /home/cdw/omf/trunk/emulab/obj/os/imagezip-080901/ntfs/libntfs/ntfsprogs/missing makeinfo
OBJDUMP = @OBJDUMP@
OBJEXT = o
PACKAGE = ntfsprogs
RANLIB = ranlib
STRIP = strip
VERSION = 1.7.1
all_includes =  
all_libraries =  

LTVERSION = 4:0:0
#AM_CFLAGS = #-D_FILE_OFFSET_BITS=64 -Wall -g -DDEBUG
AM_CFLAGS = -D_FILE_OFFSET_BITS=64 -Wall

linux_ntfsincludedir = -I$(top_srcdir)/include
lib_LTLIBRARIES = libntfs.la
libntfs_la_LDFLAGS = -version-info $(LTVERSION)
libntfs_la_SOURCES = \
	attrib.c	\
	bitmap.c	\
	bootsect.c	\
	compat.c	\
	debug.c		\
	dir.c		\
	disk_io.c	\
	inode.c		\
	lcnalloc.c	\
	mft.c		\
	mst.c		\
	runlist.c	\
	unistr.c	\
	volume.c


INCLUDES = $(linux_ntfsincludedir) $(all_includes)
mkinstalldirs = $(SHELL) $(top_srcdir)/mkinstalldirs
CONFIG_HEADER = ../config.h
CONFIG_CLEAN_FILES = 
LTLIBRARIES =  $(lib_LTLIBRARIES)


DEFS = -DHAVE_CONFIG_H -I. -I$(srcdir) -I..
LIBS = 
libntfs_la_LIBADD = 
libntfs_la_OBJECTS =  attrib.lo bitmap.lo bootsect.lo compat.lo debug.lo \
dir.lo disk_io.lo inode.lo lcnalloc.lo mft.lo mst.lo runlist.lo \
unistr.lo volume.lo
COMPILE = $(CC) $(DEFS) $(INCLUDES) $(AM_CPPFLAGS) $(CPPFLAGS) $(AM_CFLAGS) $(CFLAGS)
LTCOMPILE = $(LIBTOOL) --mode=compile $(CC) $(DEFS) $(INCLUDES) $(AM_CPPFLAGS) $(CPPFLAGS) $(AM_CFLAGS) $(CFLAGS)
CCLD = $(CC)
LINK = $(LIBTOOL) --mode=link $(CCLD) $(AM_CFLAGS) $(CFLAGS) $(LDFLAGS) -o $@
DIST_COMMON =  Makefile.am Makefile.in


DISTFILES = $(DIST_COMMON) $(SOURCES) $(HEADERS) $(TEXINFOS) $(EXTRA_DIST)

TAR = gtar
GZIP_ENV = --best
SOURCES = $(libntfs_la_SOURCES)
OBJECTS = $(libntfs_la_OBJECTS)

all: all-redirect
.SUFFIXES:
.SUFFIXES: .S .c .lo .o .obj .s
$(srcdir)/Makefile.in: # Makefile.am $(top_srcdir)/configure.in $(ACLOCAL_M4) 
	cd $(top_srcdir) && $(AUTOMAKE) --gnu --include-deps libntfs/Makefile

Makefile: $(srcdir)/Makefile.in  $(top_builddir)/config.status
	cd $(top_builddir) \
	  && CONFIG_FILES=$(subdir)/$@ CONFIG_HEADERS= $(SHELL) ./config.status


mostlyclean-libLTLIBRARIES:

clean-libLTLIBRARIES:
	-test -z "$(lib_LTLIBRARIES)" || rm -f $(lib_LTLIBRARIES)

distclean-libLTLIBRARIES:

maintainer-clean-libLTLIBRARIES:

install-libLTLIBRARIES: $(lib_LTLIBRARIES)
	@$(NORMAL_INSTALL)
	$(mkinstalldirs) $(DESTDIR)$(libdir)
	@list='$(lib_LTLIBRARIES)'; for p in $$list; do \
	  if test -f $$p; then \
	    echo "$(LIBTOOL)  --mode=install $(INSTALL) $$p $(DESTDIR)$(libdir)/$$p"; \
	    $(LIBTOOL)  --mode=install $(INSTALL) $$p $(DESTDIR)$(libdir)/$$p; \
	  else :; fi; \
	done

uninstall-libLTLIBRARIES:
	@$(NORMAL_UNINSTALL)
	list='$(lib_LTLIBRARIES)'; for p in $$list; do \
	  $(LIBTOOL)  --mode=uninstall rm -f $(DESTDIR)$(libdir)/$$p; \
	done

.c.o:
	$(COMPILE) -c $<

# FIXME: We should only use cygpath when building on Windows,
# and only if it is available.
.c.obj:
	$(COMPILE) -c `cygpath -w $<`

.s.o:
	$(COMPILE) -c $<

.S.o:
	$(COMPILE) -c $<

mostlyclean-compile:
	-rm -f *.o core *.core
	-rm -f *.$(OBJEXT)

clean-compile:

distclean-compile:
	-rm -f *.tab.c

maintainer-clean-compile:

.c.lo:
	$(LIBTOOL) --mode=compile $(COMPILE) -c $<

.s.lo:
	$(LIBTOOL) --mode=compile $(COMPILE) -c $<

.S.lo:
	$(LIBTOOL) --mode=compile $(COMPILE) -c $<

mostlyclean-libtool:
	-rm -f *.lo

clean-libtool:
	-rm -rf .libs _libs

distclean-libtool:

maintainer-clean-libtool:

libntfs.la: $(libntfs_la_OBJECTS) $(libntfs_la_DEPENDENCIES)
	$(LINK) -rpath $(libdir) $(libntfs_la_LDFLAGS) $(libntfs_la_OBJECTS) $(libntfs_la_LIBADD) $(LIBS)

tags: TAGS

ID: $(HEADERS) $(SOURCES) $(LISP)
	list='$(SOURCES) $(HEADERS)'; \
	unique=`for i in $$list; do echo $$i; done | \
	  awk '    { files[$$0] = 1; } \
	       END { for (i in files) print i; }'`; \
	here=`pwd` && cd $(srcdir) \
	  && mkid -f$$here/ID $$unique $(LISP)

TAGS:  $(HEADERS) $(SOURCES)  $(TAGS_DEPENDENCIES) $(LISP)
	tags=; \
	here=`pwd`; \
	list='$(SOURCES) $(HEADERS)'; \
	unique=`for i in $$list; do echo $$i; done | \
	  awk '    { files[$$0] = 1; } \
	       END { for (i in files) print i; }'`; \
	test -z "$(ETAGS_ARGS)$$unique$(LISP)$$tags" \
	  || (cd $(srcdir) && etags $(ETAGS_ARGS) $$tags  $$unique $(LISP) -o $$here/TAGS)

mostlyclean-tags:

clean-tags:

distclean-tags:
	-rm -f TAGS ID

maintainer-clean-tags:

distdir = $(top_builddir)/$(PACKAGE)-$(VERSION)/$(subdir)

subdir = libntfs

distdir: $(DISTFILES)
	@for file in $(DISTFILES); do \
	  d=$(srcdir); \
	  if test -d $$d/$$file; then \
	    cp -pr $$d/$$file $(distdir)/$$file; \
	  else \
	    test -f $(distdir)/$$file \
	    || ln $$d/$$file $(distdir)/$$file 2> /dev/null \
	    || cp -p $$d/$$file $(distdir)/$$file || :; \
	  fi; \
	done
attrib.lo attrib.o : attrib.c ../include/compat.h ../include/attrib.h \
	../include/types.h ../include/unistr.h ../include/layout.h \
	../include/endians.h ../include/support.h ../include/runlist.h \
	../include/volume.h ../config.h ../include/inode.h \
	../include/disk_io.h ../include/mft.h ../include/debug.h \
	../include/mst.h ../include/lcnalloc.h
bitmap.lo bitmap.o : bitmap.c ../include/types.h ../include/attrib.h \
	../include/unistr.h ../include/layout.h ../include/endians.h \
	../include/support.h ../include/runlist.h ../include/volume.h \
	../config.h ../include/inode.h ../include/bitmap.h
bootsect.lo bootsect.o : bootsect.c ../include/compat.h \
	../include/bootsect.h ../include/types.h ../include/volume.h \
	../config.h ../include/support.h ../include/inode.h \
	../include/runlist.h ../include/attrib.h ../include/unistr.h \
	../include/layout.h ../include/endians.h ../include/debug.h
compat.lo compat.o : compat.c
debug.lo debug.o : debug.c ../include/debug.h ../config.h \
	../include/attrib.h ../include/types.h ../include/unistr.h \
	../include/layout.h ../include/endians.h ../include/support.h \
	../include/runlist.h ../include/volume.h ../include/inode.h
dir.lo dir.o : dir.c ../include/types.h ../include/debug.h ../config.h \
	../include/attrib.h ../include/unistr.h ../include/layout.h \
	../include/endians.h ../include/support.h ../include/runlist.h \
	../include/volume.h ../include/inode.h ../include/dir.h
disk_io.lo disk_io.o : disk_io.c ../config.h ../include/types.h \
	../include/disk_io.h ../include/volume.h ../include/support.h \
	../include/inode.h ../include/runlist.h ../include/attrib.h \
	../include/unistr.h ../include/layout.h ../include/endians.h \
	../include/mst.h ../include/debug.h
inode.lo inode.o : inode.c ../include/compat.h ../include/types.h \
	../include/inode.h ../include/support.h ../include/runlist.h \
	../include/attrib.h ../include/unistr.h ../include/layout.h \
	../include/endians.h ../include/volume.h ../config.h \
	../include/debug.h ../include/mft.h
lcnalloc.lo lcnalloc.o : lcnalloc.c ../include/types.h \
	../include/attrib.h ../include/unistr.h ../include/layout.h \
	../include/endians.h ../include/support.h ../include/runlist.h \
	../include/volume.h ../config.h ../include/inode.h \
	../include/bitmap.h ../include/debug.h ../include/lcnalloc.h
mft.lo mft.o : mft.c ../include/compat.h ../include/types.h \
	../include/disk_io.h ../include/volume.h ../config.h \
	../include/support.h ../include/inode.h ../include/runlist.h \
	../include/attrib.h ../include/unistr.h ../include/layout.h \
	../include/endians.h ../include/debug.h ../include/bitmap.h \
	../include/mft.h
mst.lo mst.o : mst.c ../include/mst.h ../include/types.h \
	../include/layout.h ../include/endians.h ../include/support.h
runlist.lo runlist.o : runlist.c ../include/compat.h ../include/types.h \
	../include/attrib.h ../include/unistr.h ../include/layout.h \
	../include/endians.h ../include/support.h ../include/runlist.h \
	../include/volume.h ../config.h ../include/inode.h \
	../include/debug.h ../include/disk_io.h
unistr.lo unistr.o : unistr.c ../include/types.h ../include/unistr.h \
	../include/layout.h ../include/endians.h ../include/support.h \
	../include/debug.h ../config.h ../include/attrib.h \
	../include/runlist.h ../include/volume.h ../include/inode.h
volume.lo volume.o : volume.c ../include/volume.h ../config.h \
	../include/types.h ../include/support.h ../include/inode.h \
	../include/runlist.h ../include/attrib.h ../include/unistr.h \
	../include/layout.h ../include/endians.h ../include/mft.h \
	../include/bootsect.h ../include/disk_io.h ../include/debug.h

info-am:
info: info-am
dvi-am:
dvi: dvi-am
check-am: all-am
check: check-am
installcheck-am:
installcheck: installcheck-am
install-exec-am: install-libLTLIBRARIES
install-exec: install-exec-am

install-data-am:
install-data: install-data-am

install-am: all-am
	@$(MAKE) $(AM_MAKEFLAGS) install-exec-am install-data-am
install: install-am
uninstall-am: uninstall-libLTLIBRARIES
uninstall: uninstall-am
all-am: Makefile $(LTLIBRARIES)
all-redirect: all-am
install-strip:
	$(MAKE) $(AM_MAKEFLAGS) AM_INSTALL_PROGRAM_FLAGS=-s install
installdirs:
	$(mkinstalldirs)  $(DESTDIR)$(libdir)


mostlyclean-generic:

clean-generic:

distclean-generic:
	-rm -f Makefile $(CONFIG_CLEAN_FILES)
	-rm -f config.cache config.log stamp-h stamp-h[0-9]*

maintainer-clean-generic:
mostlyclean-am:  mostlyclean-libLTLIBRARIES mostlyclean-compile \
		mostlyclean-libtool mostlyclean-tags \
		mostlyclean-generic

mostlyclean: mostlyclean-am

clean-am:  clean-libLTLIBRARIES clean-compile clean-libtool clean-tags \
		clean-generic mostlyclean-am

clean: clean-am

distclean-am:  distclean-libLTLIBRARIES distclean-compile \
		distclean-libtool distclean-tags distclean-generic \
		clean-am
	-rm -f libtool

distclean: distclean-am

maintainer-clean-am:  maintainer-clean-libLTLIBRARIES \
		maintainer-clean-compile maintainer-clean-libtool \
		maintainer-clean-tags maintainer-clean-generic \
		distclean-am
	@echo "This command is intended for maintainers to use;"
	@echo "it deletes files that may require special tools to rebuild."

maintainer-clean: maintainer-clean-am

.PHONY: mostlyclean-libLTLIBRARIES distclean-libLTLIBRARIES \
clean-libLTLIBRARIES maintainer-clean-libLTLIBRARIES \
uninstall-libLTLIBRARIES install-libLTLIBRARIES mostlyclean-compile \
distclean-compile clean-compile maintainer-clean-compile \
mostlyclean-libtool distclean-libtool clean-libtool \
maintainer-clean-libtool tags mostlyclean-tags distclean-tags \
clean-tags maintainer-clean-tags distdir info-am info dvi-am dvi check \
check-am installcheck-am installcheck install-exec-am install-exec \
install-data-am install-data install-am install uninstall-am uninstall \
all-redirect all-am all installdirs mostlyclean-generic \
distclean-generic clean-generic maintainer-clean-generic clean \
mostlyclean distclean maintainer-clean


# Tell versions [3.59,3.63) of GNU make to not export all variables.
# Otherwise a system limit (for SysV at least) may be exceeded.
.NOEXPORT:
