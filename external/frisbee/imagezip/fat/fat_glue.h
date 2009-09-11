/*
 * Copyright (c) 2003 University of Utah and the Flux Group.
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
 * Glue to code from fsck_msdosfs
 */

#include <err.h>
#include <sys/types.h>
#include "dosfs.h"

#define	FSOK		0		/* Check was OK */
#define	FSBOOTMOD	1		/* Boot block was modified */
#define	FSDIRMOD	2		/* Some directory was modified */
#define	FSFATMOD	4		/* The FAT was modified */
#define	FSERROR		8		/* Some unrecovered error remains */
#define	FSFATAL		16		/* Some unrecoverable error occured */
#define FSDIRTY		32		/* File system is dirty */
#define FSFIXFAT	64		/* Fix file system FAT */

int readboot(int fd, struct bootblock *boot);
int readfat(int fd, struct bootblock *boot, int no, struct fatEntry **fp);
void fat_addskip(struct bootblock *boot, int startcl, int ncl);
off_t fat_lseek(int fd, off_t off, int whence);
ssize_t devread(int fd, void *buf, size_t nbytes);

#define lseek(f,o,w)	fat_lseek((f), (o), (w))
#define read(f,b,s)	devread((f), (b), (s))
#define pfatal		warnx
#define pwarn		warnx

#ifndef __RCSID
#define __RCSID(s)
#endif
