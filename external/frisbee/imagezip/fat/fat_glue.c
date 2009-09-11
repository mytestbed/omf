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

#include <stdlib.h>
#include <assert.h>
#include <stdio.h>
#include <unistd.h>
#include <sys/param.h>

#include "sliceinfo.h"
#include "global.h"
#include "fat_glue.h"

/* XXX */
extern int debug;
extern void addskip(uint32_t start, uint32_t size);
extern int secsize;
#define sectobytes(s)	((off_t)(s) * secsize)
#define bytestosec(b)	(uint32_t)((b) / secsize)

static u_int32_t fat_offset, fat_limit;
static int fatsecpersec;

int
read_fatslice(int slice, int stype, u_int32_t start, u_int32_t size,
	      char *sfilename, int infd)
{
	struct bootblock boot;
	struct fatEntry *fat = NULL;

	fat_offset = start;
	if (size > 0)
		fat_limit = start + size;

	if (fat_lseek(infd, 0, SEEK_SET) == -1) {
		warnx("FAT Slice %d: Could not seek to boot sector", slice+1);
		return 1;
	}

	if (readboot(infd, &boot) != FSOK)
		return 1;

	if (debug)
		fprintf(stderr, "FAT Slice %d: FAT%d filesystem found\n",
			slice+1,
			boot.ClustMask == CLUST32_MASK ? 32 :
			boot.ClustMask == CLUST16_MASK ? 16 : 12);

	fatsecpersec = boot.BytesPerSec / secsize;
	if (fatsecpersec * secsize != boot.BytesPerSec) {
		warnx("FAT Slice %d: FAT sector size (%d) not a multiple of %d",
		      slice+1, boot.BytesPerSec, secsize);
		return 1;
	}

	if (readfat(infd, &boot, boot.ValidFat >= 0 ?: 0, &fat) != FSOK)
		return 1;
	free(fat);

	if (debug)
		fprintf(stderr, "        NumFree %9d, NumClusters %9d\n",
			boot.NumFree, boot.NumClusters);
	return 0;
}

void
fat_addskip(struct bootblock *boot, int startcl, int ncl)
{
	uint32_t start, size;

	start = startcl * boot->SecPerClust + boot->ClusterOffset;
	size = ncl * boot->SecPerClust;
	if (fatsecpersec != 1) {
		start /= fatsecpersec;
		size /= fatsecpersec;
	}

	start += fat_offset;
	assert(fat_limit == 0 || start + size <= fat_limit);

	if (debug > 1)
		fprintf(stderr, "        CL%d-%d\t offset %9u, free %6u\n",
			startcl, startcl + ncl - 1, start, size);

	addskip(start, size);
}

#undef lseek
off_t
fat_lseek(int fd, off_t off, int whence)
{
	off_t noff;

	assert(whence == SEEK_SET);

	off += sectobytes(fat_offset);
	assert(fat_limit == 0 || off < sectobytes(fat_limit));
	assert((off & (DEV_BSIZE-1)) == 0);

	noff = lseek(fd, off, whence) - sectobytes(fat_offset);
	assert(noff == (off_t)-1 || (noff & (DEV_BSIZE-1)) == 0);

	return noff;
}
