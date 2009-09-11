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

#include "ffs.h"
#include "sliceinfo.h"
#include "global.h"
#include "imagehdr.h"

static int read_bsdpartition(int infd, struct disklabel *dlabel, int part);
static int read_bsdsblock(int infd, u_int32_t off, int part, struct fs *fsp);
static int read_bsdcg(struct fs *fsp, struct cg *cgp, unsigned int dbstart);

/* Map partition number to letter */
#define BSDPARTNAME(i)       ("abcdefghijklmnop"[(i)])

static int32_t freecount;

/*
 * Operate on a BSD slice
 */
int
read_bsdslice(int slice, int bsdtype, u_int32_t start, u_int32_t size,
	      char *sname, int infd)
{
	int		cc, i, rval = 0, npart;
	union {
		struct disklabel	label;
		char			pad[BBSIZE];
	} dlabel;

	if (debug)
		fprintf(stderr, "  P%d (%sBSD Slice)\n", slice + 1,
			bsdtype == DOSPTYP_386BSD ? "Free" : "Open");
	
	if (devlseek(infd, sectobytes(start), SEEK_SET) < 0) {
		warn("Could not seek to beginning of BSD slice");
		return 1;
	}

	/*
	 * Then seek ahead to the disklabel.
	 */
	if (devlseek(infd, sectobytes(LABELSECTOR), SEEK_CUR) < 0) {
		warn("Could not seek to beginning of BSD disklabel");
		return 1;
	}

	if ((cc = devread(infd, &dlabel, sizeof(dlabel))) < 0) {
		warn("Could not read BSD disklabel");
		return 1;
	}
	if (cc != sizeof(dlabel)) {
		warnx("Could not get the entire BSD disklabel");
 		return 1;
	}

	/*
	 * Check the magic numbers.
	 */
	if (dlabel.label.d_magic  != DISKMAGIC ||
	    dlabel.label.d_magic2 != DISKMAGIC) {
#if 0 /* not needed, a fake disklabel is created by the kernel */
		/*
		 * If we were forced with the bsdfs option,
		 * assume this is a single partition disk like a
		 * memory or vnode disk.  We cons up a disklabel
		 * and let it rip.
		 */
		if (size == 0) {
			fprintf(stderr,
				"No disklabel, assuming single partition\n");
			dlabel.label.d_partitions[0].p_offset = 0;
			dlabel.label.d_partitions[0].p_size = 0;
			dlabel.label.d_partitions[0].p_fstype = FS_BSDFFS;
			return read_bsdpartition(infd, &dlabel.label, 0);
		}
#endif
		warnx("Wrong magic number is BSD disklabel");
 		return 1;
	}

	/*
	 * Now scan partitions.
	 *
	 * XXX space not covered by a partition winds up being compressed,
	 * we could detect this.
	 */
	npart = dlabel.label.d_npartitions;
	assert(npart >= 0 && npart <= 16);
	if (debug)
		fprintf(stderr, "  P%d: %d partitions\n", slice+1, npart);
	for (i = 0; i < npart; i++) {
		if (! dlabel.label.d_partitions[i].p_size)
			continue;

		if (dlabel.label.d_partitions[i].p_fstype == FS_UNUSED)
			continue;

		/*
		 * OpenBSD maps the extended DOS partitions as slices 8-15,
		 * skip them.
		 */
		if (bsdtype == DOSPTYP_OPENBSD && i >= 8 && i < 16) {
			if (debug)
				fprintf(stderr, "    '%c'   skipping, "
					"OpenBSD mapping of DOS partition %d\n",
					BSDPARTNAME(i), i - 6);
			continue;
		}

		if (debug) {
			fprintf(stderr, "    '%c' ", BSDPARTNAME(i));

			fprintf(stderr, "start %9d, size %9d\t(%s)\n",
			   dlabel.label.d_partitions[i].p_offset,
			   dlabel.label.d_partitions[i].p_size,
			   fstypenames[dlabel.label.d_partitions[i].p_fstype]);
		}

		if (ignore[slice] & (1 << i)) {
			fprintf(stderr, "  Slice %d BSD partition '%c' ignored,"
				" NOT SAVING.\n",
				slice + 1, BSDPARTNAME(i));
			addskip(dlabel.label.d_partitions[i].p_offset,
				dlabel.label.d_partitions[i].p_size);
		} else if (forceraw[slice] & (1 << i)) {
			fprintf(stderr, "  Slice %d BSD partition '%c',"
				" forcing raw compression.\n",
				slice + 1, BSDPARTNAME(i));
		} else {
			rval = read_bsdpartition(infd, &dlabel.label, i);
			if (rval)
				return rval;
		}
	}
	
	/*
	 * Record a fixup for the partition table, adjusting the
	 * partition offsets to make them slice relative.
	 */
	if (dorelocs &&
	    start != 0 && dlabel.label.d_partitions[0].p_offset == start) {
		for (i = 0; i < npart; i++) {
			if (dlabel.label.d_partitions[i].p_size == 0)
				continue;

			/*
			 * Don't mess with OpenBSD partitions 8-15 which map
			 * extended DOS partitions.  Also leave raw partition
			 * alone as it maps the entire disk (not just slice)
			 */
			if (bsdtype == DOSPTYP_OPENBSD &&
			    (i == 2 || (i >= 8 && i < 16)))
				continue;

			assert(dlabel.label.d_partitions[i].p_offset >= start);
			dlabel.label.d_partitions[i].p_offset -= start;
		}
		dlabel.label.d_checksum = 0;
		dlabel.label.d_checksum = dkcksum(&dlabel.label);

		addfixup(sectobytes(start+LABELSECTOR),
			 sectobytes(start),
			 (off_t)sizeof(dlabel.label), &dlabel,
			 bsdtype == DOSPTYP_OPENBSD ?
			 RELOC_OBSDDISKLABEL : RELOC_FBSDDISKLABEL);
	}

	return 0;
}

/*
 * BSD partition table offsets are relative to the start of the raw disk.
 * Very convenient.
 */
static int
read_bsdpartition(int infd, struct disklabel *dlabel, int part)
{
	int		i, cc, rval = 0;
	struct fs	fs;
	union {
		struct cg cg;
		char pad[MAXBSIZE];
	} cg;
	u_int32_t	size, offset;
	int32_t		sbfree;

	offset = dlabel->d_partitions[part].p_offset;
	size   = dlabel->d_partitions[part].p_size;
	
	if (dlabel->d_partitions[part].p_fstype == FS_SWAP) {
		addskip(offset, size);
		return 0;
	}

	if (dlabel->d_partitions[part].p_fstype != FS_BSDFFS) {
		warnx("BSD Partition '%c': Not a BSD Filesystem",
		      BSDPARTNAME(part));
		return 1;
	}

	if (read_bsdsblock(infd, offset, part, &fs))
		return 1;

	sbfree = (fs.fs_cstotal.cs_nbfree * fs.fs_frag) +
		fs.fs_cstotal.cs_nffree;

	if (debug) {
		fprintf(stderr, "        bfree %9qd, bsize %9d, cgsize %9d\n",
			fs.fs_cstotal.cs_nbfree, fs.fs_bsize, fs.fs_cgsize);
	}
	assert(fs.fs_cgsize <= MAXBSIZE);
	assert((fs.fs_cgsize % secsize) == 0);

	freecount = 0;
	for (i = 0; i < fs.fs_ncg; i++) {
		unsigned long	cgoff, dboff;

		cgoff = fsbtodb(&fs, cgtod(&fs, i)) + offset;
		dboff = fsbtodb(&fs, cgbase(&fs, i)) + offset;

		if (devlseek(infd, sectobytes(cgoff), SEEK_SET) < 0) {
			warn("BSD Partition '%c': "
			     "Could not seek to cg %d at %qd",
			     BSDPARTNAME(part), i, sectobytes(cgoff));
			return 1;
		}
		if ((cc = devread(infd, &cg, fs.fs_cgsize)) < 0) {
			warn("BSD Partition '%c': Could not read cg %d",
			     BSDPARTNAME(part), i);
			return 1;
		}
		if (cc != fs.fs_cgsize) {
			warn("BSD Partition '%c': Truncated cg %d",
			     BSDPARTNAME(part), i);
			return 1;
		}
		if (debug > 1) {
			fprintf(stderr,
				"        CG%d\t offset %9ld, bfree %6d\n",
				i, cgoff, cg.cg.cg_cs.cs_nbfree);
		}
		
		rval = read_bsdcg(&fs, &cg.cg, dboff);
		if (rval)
			return rval;
	}

	if (rval == 0 && freecount != sbfree) {
		warnx("BSD Partition '%c': "
		      "computed free count (%d) != expected free count (%d)",
		      BSDPARTNAME(part), freecount, sbfree);
	}

	return rval;
}

/*
 * Includes code yanked from UFS2 ffs_vfsops.c
 */
static int
read_bsdsblock(int infd, u_int32_t offset, int part, struct fs *fsp)
{
	static int sblock_try[] = SBLOCKSEARCH;
	union {
		struct fs fs;
		char pad[SBLOCKSIZE];
	} fsu;
	struct fs *fs = &fsu.fs;
	int sblockloc = 0, altsblockloc = -1;
	int cc, i;

	/*
	 * Try reading the superblock in each of its possible locations.
	 */
	i = 0;
 tryagain:
	for ( ; sblock_try[i] != -1; i++) {
		off_t sbloc = sectobytes(offset) + sblock_try[i];

		if (devlseek(infd, sbloc, SEEK_SET) < 0) {
			warnx("BSD Partition '%c': "
			      "Could not seek to superblock",
			      BSDPARTNAME(part));
			return 1;
		}

		if ((cc = devread(infd, &fsu, SBLOCKSIZE)) < 0) {
			warn("BSD Partition '%c': Could not read superblock",
			     BSDPARTNAME(part));
			return 1;
		}
		if (cc != SBLOCKSIZE) {
			warnx("BSD Partition '%c': Truncated superblock",
			      BSDPARTNAME(part));
			return 1;
		}

		sblockloc = sblock_try[i];
		if ((fs->fs_magic == FS_UFS1_MAGIC ||
		     (fs->fs_magic == FS_UFS2_MAGIC &&
		      (fs->fs_sblockloc == sblockloc ||
		       (fs->fs_old_flags & FS_FLAGS_UPDATED) == 0))) &&
		    fs->fs_bsize <= MAXBSIZE &&
		    fs->fs_bsize >= sizeof(struct fs)) {
			/*
			 * Found a UFS1 superblock at something other
			 * than the UFS1 location, might be an alternate
			 * superblock that is out of date so continue
			 * looking for the primary superblock.
			 */
			if (fs->fs_magic == FS_UFS1_MAGIC &&
			    sblockloc != SBLOCK_UFS1 && altsblockloc == -1) {
				altsblockloc = i;
				continue;
			}
			break;
		}
	}
	if (sblock_try[i] == -1) {
		/*
		 * We had found a previous, valid UFS1 superblock at a
		 * non-standard location.  Go back and use that one.
		 */
		if (altsblockloc != -1) {
			i = altsblockloc;
			goto tryagain;
		}
		warnx("BSD Partition '%c': No superblock found",
		      BSDPARTNAME(part));
		return 1;
	}
	if (fs->fs_clean == 0)
		warnx("BSD Partition '%c': WARNING filesystem not clean",
		      BSDPARTNAME(part));
	if (fs->fs_pendingblocks != 0 || fs->fs_pendinginodes != 0)
		warnx("BSD Partition '%c': "
		      "WARNING filesystem has pending blocks/files",
		      BSDPARTNAME(part));

	if (debug)
		fprintf(stderr, "    '%c' UFS%d, superblock at %d\n",
			BSDPARTNAME(part),
			fs->fs_magic == FS_UFS2_MAGIC ? 2 : 1,
			sblockloc);

	/*
	 * Copy UFS1 fields into newer, roomier UFS2 equivs that we use
	 * in our code.
	 */
	if (fs->fs_magic == FS_UFS1_MAGIC && fs->fs_maxbsize != fs->fs_bsize) {
		fs->fs_maxbsize = fs->fs_bsize;
		fs->fs_size = fs->fs_old_size;
		fs->fs_dsize = fs->fs_old_dsize;
		fs->fs_cstotal.cs_nbfree = fs->fs_old_cstotal.cs_nbfree;
		fs->fs_cstotal.cs_nffree = fs->fs_old_cstotal.cs_nffree;
	}

	*fsp = *fs;
	return 0;
}

static int
read_bsdcg(struct fs *fsp, struct cg *cgp, unsigned int dbstart)
{
	int  i, max;
	char *p;
	int count, j;

	max = fsp->fs_fpg;
	p   = cg_blksfree(cgp);

	/* paranoia: make sure we stay in the buffer */
	assert(&p[max/NBBY] <= (char *)cgp + fsp->fs_cgsize);

	/*
	 * XXX The bitmap is fragments, not FS blocks.
	 *
	 * The block bitmap lists blocks relative to the base (cgbase()) of
	 * the cylinder group. cgdmin() is the first actual datablock, but
	 * the bitmap includes all the blocks used for all the blocks
	 * comprising the cg. These include the superblock, cg, inodes,
	 * datablocks and the variable-sized padding before all of these
	 * (used to skew the offset of consecutive cgs).
	 * The "dbstart" parameter is thus the beginning of the cg, to which
	 * we add the bitmap offset. All blocks before cgdmin() will always
	 * be allocated, but we scan them anyway. 
	 */

	if (debug > 2)
		fprintf(stderr, "                 ");
	for (count = i = 0; i < max; i++)
		if (isset(p, i)) {
			unsigned long dboff, dbcount;

			j = i;
			while ((i+1)<max && isset(p, i+1))
				i++;

			dboff = dbstart + fsbtodb(fsp, j);
			dbcount = fsbtodb(fsp, (i-j) + 1);
			freecount += (i-j) + 1;
					
			if (debug > 2) {
				if (count)
					fprintf(stderr, ",%s",
						count % 4 ?
						" " : "\n                 ");
				fprintf(stderr, "%lu:%ld", dboff, dbcount);
			}
			addskip(dboff, dbcount);
			count++;
		}
	if (debug > 2)
		fprintf(stderr, "\n");
	return 0;
}

