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
 * Global defns that should go away someday
 */
extern int debug;
extern int secsize;
extern int slicemode;
extern int dorelocs;

extern char *slicename(int slice, u_int32_t offset, u_int32_t size, int type);
extern off_t devlseek(int fd, off_t off, int whence);
extern ssize_t devread(int fd, void *buf, size_t nbytes);
extern void addskip(uint32_t start, uint32_t size);
extern void addfixup(off_t offset, off_t poffset, off_t size, void *data,
		     int reloctype);

extern SLICEMAP_PROCESS_PROTO(read_bsdslice);
extern SLICEMAP_PROCESS_PROTO(read_linuxslice);
extern SLICEMAP_PROCESS_PROTO(read_linuxswap);
extern SLICEMAP_PROCESS_PROTO(read_ntfsslice);
extern SLICEMAP_PROCESS_PROTO(read_fatslice);

#define sectobytes(s)	((off_t)(s) * secsize)
#define bytestosec(b)	(uint32_t)((b) / secsize)
