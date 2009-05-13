/*
 * Copyright (c) 2003-2005 University of Utah and the Flux Group.
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

#include <stdlib.h>
#include <assert.h>
#include <stdio.h>
#include <unistd.h>
#include <sys/param.h>

#include "sliceinfo.h"
#include "global.h"
#include "fat_glue.h"

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

	if (readfat(infd, &boot,
		    boot.ValidFat >= 0 ? boot.ValidFat : 0, &fat) != FSOK)
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
