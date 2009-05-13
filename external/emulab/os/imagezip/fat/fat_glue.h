/*
 * Copyright (c) 2003 University of Utah and the Flux Group.
 * All rights reserved.
 * This file is part of the Emulab network testbed software.
 * 
 * Emulab is free software, also known as "open source;" you can
 * redistribute it and/or modify it under the terms of the GNU Affero
 * General Public License as published by the Free Software Foundation,
 * either version 3 of the License, or (at your option) any later version.
 * 
 * Emulab is distributed in the hope that it will be useful, but WITHOUT ANY
 * WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
 * FOR A PARTICULAR PURPOSE.  See the GNU Affero General Public License for
 * more details, which can be found in the file AGPL-COPYING at the root of
 * the source tree.
 * 
 * You should have received a copy of the GNU Affero General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
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
