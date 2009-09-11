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

#include <stdio.h>
#include <err.h>
#include <assert.h>
#include <sys/param.h>
#include <ext2_fs.h>

#include "sliceinfo.h"
#include "global.h"

static int read_linuxgroup(struct ext2_super_block *super,
			   struct ext2_group_desc *group, int index,
			   u_int32_t sliceoffset, int infd);

extern int fixup_lilo(int slice, int stype, u_int32_t start, u_int32_t size,
		      char *sname, int infd, int *found);


/*
 * Operate on a linux slice. I actually don't have a clue what a linux
 * slice looks like. I just know that in our images, the linux slice
 * has the boot block in the first sector, part of the boot in the
 * second sector, and then the superblock for the one big filesystem
 * in the 3rd sector. Just start there and move on.
 *
 * Unlike BSD partitions, linux block offsets are from the start of the
 * slice, so we have to add the starting sector to everything. 
 */
int
read_linuxslice(int slice, int stype, u_int32_t start, u_int32_t size,
		char *sname, int infd)
{
#define LINUX_SUPERBLOCK_OFFSET	1024
#define LINUX_SUPERBLOCK_SIZE 	1024
#define LINUX_MAXGRPSPERBLK	\
	(EXT2_MAX_BLOCK_SIZE/sizeof(struct ext2_group_desc))

	int			cc, i, numgroups, rval = 0;
	struct ext2_super_block	fs;
	struct ext2_group_desc	groups[LINUX_MAXGRPSPERBLK];
	int			dosslice = slice + 1; /* DOS Numbering */
	off_t			soff;

	/*
	 * Check for a LILO boot block and create relocations as necessary
	 * (if the partition starts at 0, the values are already relative)
	 */
	if (dorelocs && start > 0 &&
	    fixup_lilo(slice, stype, start, size, sname, infd, &rval) != 0)
		return 1;

	assert((sizeof(fs) & ~LINUX_SUPERBLOCK_SIZE) == 0);
	assert((sizeof(groups) & ~EXT2_MAX_BLOCK_SIZE) == 0);

	if (debug)
		fprintf(stderr, "  P%d %s Linux Slice)\n",
			dosslice, rval ? "(Bootable" : "(");
	
	/*
	 * Skip ahead to the superblock.
	 */
	if (devlseek(infd, sectobytes(start) + LINUX_SUPERBLOCK_OFFSET,
		     SEEK_SET) < 0) {
		warnx("Linux Slice %d: Could not seek to superblock",
		      dosslice);
		return 1;
	}

	if ((cc = devread(infd, &fs, LINUX_SUPERBLOCK_SIZE)) < 0) {
		warn("Linux Slice %d: Could not read superblock", dosslice);
		return 1;
	}
	if (cc != LINUX_SUPERBLOCK_SIZE) {
		warnx("Linux Slice %d: Truncated superblock", dosslice);
		return 1;
	}
 	if (fs.s_magic != EXT2_SUPER_MAGIC) {
		warnx("Linux Slice %d: Bad magic number in superblock",
		      dosslice);
 		return (1);
 	}
	if (EXT2_BLOCK_SIZE(&fs) < EXT2_MIN_BLOCK_SIZE ||
	    EXT2_BLOCK_SIZE(&fs) > EXT2_MAX_BLOCK_SIZE) {
	    warnx("Linux Slice %d: Block size not what I expect it to be: %d!",
		  dosslice, EXT2_BLOCK_SIZE(&fs));
	    return 1;
	}

	numgroups = ((fs.s_blocks_count - fs.s_first_data_block)
		     + (fs.s_blocks_per_group - 1))
		/ fs.s_blocks_per_group;
	if (debug) {
		fprintf(stderr, "        %s\n",
			(fs.s_feature_compat & 4) ? "EXT3" : "EXT2");
		fprintf(stderr, "        count %9u, size %9d, pergroup %9d\n",
			fs.s_blocks_count, EXT2_BLOCK_SIZE(&fs),
			fs.s_blocks_per_group);
		fprintf(stderr, "        bfree %9u, first %9u, groups %9d\n",
			fs.s_free_blocks_count, fs.s_first_data_block,
			numgroups);
	}

	/*
	 * Read each group descriptor. It says where the free block bitmap
	 * lives. The absolute block numbers a group descriptor refers to
	 * is determined by its index * s_blocks_per_group. Once we know where
	 * the bitmap lives, we can go out to the bitmap and see what blocks
	 * are free.
	 *
	 * Group descriptors are in the blocks right after the superblock.
	 */
	assert(LINUX_SUPERBLOCK_SIZE <= EXT2_BLOCK_SIZE(&fs));
	assert(EXT2_DESC_PER_BLOCK(&fs) * sizeof(struct ext2_group_desc)
	       == EXT2_BLOCK_SIZE(&fs)); 
	soff = sectobytes(start) +
		(fs.s_first_data_block + 1) * EXT2_BLOCK_SIZE(&fs);
	rval = 0;
	for (i = 0; i < numgroups; i++) {
		int gix;

		/*
		 * Read the group descriptors in groups since they are
		 * smaller than a sector size, packed into EXT2_BLOCK_SIZE
		 * blocks right after the superblock. 
		 */
		gix = (i % EXT2_DESC_PER_BLOCK(&fs));
		if (gix == 0) {
			if (devlseek(infd, soff, SEEK_SET) < 0) {
				warnx("Linux Slice %d: "
				      "Could not seek to Group %d",
				      dosslice, i);
				return 1;
			}

			if ((cc = devread(infd, groups, sizeof(groups))) < 0) {
				warn("Linux Slice %d: "
				     "Could not read Group %d",
				     dosslice, i);
				return 1;
			}
			if (cc != sizeof(groups)) {
				warnx("Linux Slice %d: "
				      "Truncated Group %d", dosslice, i);
				return 1;
			}
			soff += EXT2_BLOCK_SIZE(&fs);
		}

		if (debug) {
			fprintf(stderr,
				"        Group:%-2d\tBitmap %9u, bfree %9d\n",
				i, groups[gix].bg_block_bitmap,
				groups[gix].bg_free_blocks_count);
		}

		if ((rval = read_linuxgroup(&fs, &groups[gix], i, start, infd)))
			return rval;
	}
	
	return 0;
}

/*
 * A group descriptor says where on the disk the block bitmap is. Its
 * a 1bit per block map, where each bit is a FS block (instead of a
 * fragment like in BSD). Since linux offsets are relative to the start
 * of the slice, need to adjust the numbers using the slice offset.
 */
static int
read_linuxgroup(struct ext2_super_block *super,
		struct ext2_group_desc	*group,
		int index,
		u_int32_t sliceoffset /* Sector offset of slice */,
		int infd)
{
	char	*p, bitmap[EXT2_MAX_BLOCK_SIZE];
	int	i, cc, max;
	int	count, j, freecount;
	off_t	offset;
	unsigned long block;

	block = super->s_first_data_block +
		(index * super->s_blocks_per_group);

	/*
	 * Sanity check the bitmap block numbers
	 */
	if (group->bg_block_bitmap < block ||
	    group->bg_block_bitmap >= block + super->s_blocks_per_group) {
		warnx("Linux Group %d: "
		      "Group bitmap block (%d) out of range [%lu-%lu]",
		      index, group->bg_block_bitmap,
		      block, block + super->s_blocks_per_group - 1);
		return 1;
	}

	offset  = sectobytes(sliceoffset);
	offset += (off_t)EXT2_BLOCK_SIZE(super) * group->bg_block_bitmap;
	if (devlseek(infd, offset, SEEK_SET) < 0) {
		warn("Linux Group %d: "
		     "Could not seek to Group bitmap block %d",
		     index, group->bg_block_bitmap);
		return 1;
	}

	/*
	 * Sanity check this number since it the number of blocks in
	 * the group (bitmap size) is dependent on the block size. 
	 */
	if (super->s_blocks_per_group > (EXT2_BLOCK_SIZE(super) * 8)) {
	    warnx("Linux Group %d: "
		  "Block count not what I expect it to be: %d!",
		  index, super->s_blocks_per_group);
	    return 1;
	}

	if ((cc = devread(infd, bitmap, EXT2_BLOCK_SIZE(super))) < 0) {
		warn("Linux Group %d: "
		     "Could not read Group bitmap", index);
		return 1;
	}
	if (cc != EXT2_BLOCK_SIZE(super)) {
		warnx("Linux Group %d: Truncated Group bitmap", index);
		return 1;
	}

	/*
	 * The final group may have fewer than s_blocks_per_group
	 */
	max = super->s_blocks_count - block;
	if (max > super->s_blocks_per_group)
		max = super->s_blocks_per_group;
	else if (debug && max != super->s_blocks_per_group)
		fprintf(stderr,
			"        Linux Group %d: only %d blocks\n", index, max);

	p = bitmap;
	freecount = 0;

	/*
	 * XXX The bitmap is FS blocks.
	 *     The bitmap is an "inuse" map, not a free map.
	 */
#define LINUX_FSBTODB(count) \
	((EXT2_BLOCK_SIZE(super) / secsize) * (count))

	if (debug > 2)
		fprintf(stderr, "                 ");
	for (freecount = count = i = 0; i < max; i++)
		if (!isset(p, i)) {
			unsigned long dboff;
			int dbcount;

			j = i;
			while ((i+1)<max && !isset(p, i+1))
				i++;

			/*
			 * The offset of this free range, relative
			 * to the start of the disk, is: the slice
			 * offset, plus the offset of the group itself,
			 * plus the index of the first free block in
			 * the current range, plus the offset of the
			 * first data block in the filesystem.
			 */
			dboff = sliceoffset +
				LINUX_FSBTODB(index*super->s_blocks_per_group) +
				LINUX_FSBTODB(j) +
				LINUX_FSBTODB(super->s_first_data_block);

			dbcount = LINUX_FSBTODB((i-j) + 1);
					
			if (debug > 2) {
				if (count)
					fprintf(stderr, ",%s",
						count % 4 ?
						" " : "\n                 ");
				fprintf(stderr, "%lu:%d %d:%d",
					dboff, dbcount, j, i);
				count++;
			}
			addskip(dboff, dbcount);
			freecount += dbcount;
		}
	if (debug > 2)
		fprintf(stderr, "\n");

	if (freecount != LINUX_FSBTODB(group->bg_free_blocks_count)) {
		warnx("Linux Group %d: "
		      "computed free count (%d) != expected free count (%d)",
		      index, freecount, group->bg_free_blocks_count);
	}

	return 0;
}

/*
 * For a linux swap partition, all that matters is the first little
 * bit of it. The rest of it does not need to be written to disk.
 */
int
read_linuxswap(int slice, int stype, u_int32_t start, u_int32_t size,
	       char *sname, int infd)
{
	if (debug) {
		fprintf(stderr,
			"  P%d (Linux Swap)\n", slice + 1 /* DOS Numbering */);
		fprintf(stderr,
			"        start %12d, size %9d\n",
			start, size);
	}

	start += bytestosec(0x8000);
	size  -= bytestosec(0x8000);
	
	addskip(start, size);
	return 0;
}
