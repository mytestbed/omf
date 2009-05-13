/*
 * Copyright (c) 2000-2006 University of Utah and the Flux Group.
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

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <err.h>
#include <assert.h>
#include <sys/param.h>

#include "ffs.h"
#include "sliceinfo.h"
#include "global.h"
#include "imagehdr.h"

/*
 * If DO_INODES is defined, we look at the inode list in each cylinder group
 * and try to make further space reducing optimizations.  If there are
 * uninitialized inodes (UFS2 only) we add those blocks to the skip list.
 *
 * If CLEAR_FREE_INODES is also defined, we make a more dubious optimization.
 * Initialized but free inodes will go into the image data, but we first zero
 * everything except the (usually randomized) generation number in an attempt
 * to reduce the compressed size of the data.
 */
#define DO_INODES
#define CLEAR_FREE_INODES

#ifndef DO_INODES
#undef CLEAR_FREE_INODES
#endif

static int read_bsdpartition(int infd, struct disklabel *dlabel, int part);
static int read_bsdsblock(int infd, u_int32_t off, int part, struct fs *fsp);
static int read_bsdcg(struct fs *fsp, struct cg *cgp, int cg, u_int32_t off);
#ifdef CLEAR_FREE_INODES
static void inodefixup(void *buf, off_t buflen, void *fdata);
#endif

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
		fprintf(stderr, "        bfree %9lld, bsize %9d, cgsize %9d\n",
			fs.fs_cstotal.cs_nbfree, fs.fs_bsize, fs.fs_cgsize);
	}
	assert(fs.fs_cgsize <= MAXBSIZE);
	assert((fs.fs_cgsize % secsize) == 0);

	freecount = 0;
	for (i = 0; i < fs.fs_ncg; i++) {
		unsigned long	cgoff;

		cgoff = fsbtodb(&fs, cgtod(&fs, i)) + offset;

		if (devlseek(infd, sectobytes(cgoff), SEEK_SET) < 0) {
			warn("BSD Partition '%c': "
			     "Could not seek to cg %d at %lld",
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
		
		rval = read_bsdcg(&fs, &cg.cg, i, offset);
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
read_bsdcg(struct fs *fsp, struct cg *cgp, int cg, u_int32_t offset)
{
	int  i, max;
	u_int8_t *p;
	int count, j;
	unsigned long dboff, dbcount, dbstart;

	max = fsp->fs_fpg;
	p   = cg_blksfree(cgp);

	/* paranoia: make sure we stay in the buffer */
	assert(&p[max/NBBY] <= (u_int8_t *)cgp + fsp->fs_cgsize);

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
	//assert(cgbase(fsp, cg) == cgstart(fsp, cg));
	dbstart = fsbtodb(fsp, cgbase(fsp, cg)) + offset;

	if (debug > 2)
		fprintf(stderr, "                   ");
	for (count = i = 0; i < max; i++)
		if (isset(p, i)) {
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
						" " : "\n                   ");
				fprintf(stderr, "%lu:%ld", dboff, dbcount);
			}
			addskip(dboff, dbcount);
			count++;
		}
	if (debug > 2)
		fprintf(stderr, "\n");

#ifdef DO_INODES
	/*
	 * Look for free inodes
	 */
	if (cgp->cg_cs.cs_nifree != 0) {
		int tifree = 0;
		unsigned long edboff;
		int ino;

		p = cg_inosused(cgp);
		max = fsp->fs_ipg;
		assert(&p[max/NBBY] <= (u_int8_t *)cgp + fsp->fs_cgsize);

		/*
		 * For UFS2, (cylinder-group relative) inode numbers beyond
		 * initediblk are uninitialized.  We do not process those
		 * now.  They are treated as regular free blocks below.
		 */
		if (fsp->fs_magic == FS_UFS2_MAGIC) {
			assert(cgp->cg_initediblk > 0);
			assert(cgp->cg_initediblk <= fsp->fs_ipg);
			assert((cgp->cg_initediblk % INOPB(fsp)) == 0);
			max = cgp->cg_initediblk;
		}
		ino = cg * fsp->fs_ipg;

#ifdef CLEAR_FREE_INODES
		if (metaoptimize) {
			static uint32_t ufs1_magic = FS_UFS1_MAGIC;
			static uint32_t ufs2_magic = FS_UFS2_MAGIC;
			uint32_t *magic;

			if (debug > 1)
				fprintf(stderr,
					"        \t ifree  %9d\n",
					cgp->cg_cs.cs_nifree);
			if (debug > 2)
				fprintf(stderr, "                   ");

			magic = (fsp->fs_magic == FS_UFS2_MAGIC) ?
				&ufs2_magic : &ufs1_magic;
			for (count = i = 0; i < max; i++) {
				if (isset(p, i)) {
					continue;
				}
				if (ino_to_fsbo(fsp, ino+i) == 0) {
					j = i;
					while ((i+1) < max && !isset(p, i+1))
						i++;

					dboff = fsbtodb(fsp,
							ino_to_fsba(fsp, ino+j));
					edboff = fsbtodb(fsp,
							 ino_to_fsba(fsp, ino+i));
#if 0
					fprintf(stderr, "      found free inodes %d-%d"
						" db %lu.%u to %lu.%u\n",
						ino+j, ino+i,
						dboff+offset, ino_to_fsbo(fsp, ino+j),
						edboff+offset, ino_to_fsbo(fsp, ino+i));
#endif
					tifree += (i+1 - j);
					dbcount = edboff - dboff;
					if ((i+1) == max)
						dbcount++;
					if (dbcount == 0)
						continue;

					addfixupfunc(inodefixup,
						     sectobytes(dboff+offset),
						     sectobytes(offset),
						     sectobytes(dbcount),
						     magic, sizeof(magic),
						     RELOC_NONE);
					if (debug > 2) {
						if (count)
							fprintf(stderr, ",%s",
								count % 4 ?
								" " :
								"\n                   ");
						fprintf(stderr, "%lu:%ld",
							dboff+offset, dbcount);
					}
					count++;
				} else
					tifree++;
			}
			assert(i == max);

			if (debug > 2)
				fprintf(stderr, "\n");
		}
#endif

		/*
		 * For UFS2, deal with uninitialized inodes.
		 * These are sweet, we just add them to the skip list.
		 */
		if (fsp->fs_magic == FS_UFS2_MAGIC && max < fsp->fs_ipg) {
			i = max;
			if (debug > 1)
				fprintf(stderr,
					"        \t uninit %9d\n",
					fsp->fs_ipg - i);
			if (debug > 2)
				fprintf(stderr, "                   ");

			max = fsp->fs_ipg;
#if 1
			/*
			 * Paranoia!
			 */
			j = i;
			while ((j+1) < max) {
				assert(!isset(p, j+1));
				j++;
			}
#endif
			tifree += (max - i);
			dboff = fsbtodb(fsp, ino_to_fsba(fsp, ino+i));
			edboff = fsbtodb(fsp, ino_to_fsba(fsp, ino+max-1));
			dbcount = edboff - dboff + 1;

			if (debug > 2)
				fprintf(stderr, "%lu:%ld",
					dboff+offset, dbcount);

			addskip(dboff+offset, dbcount);
			if (debug > 2)
				fprintf(stderr, "\n");
		}

#ifdef CLEAR_FREE_INODES
		if (metaoptimize && tifree != cgp->cg_cs.cs_nifree)
			fprintf(stderr, "Uh-oh! found %d free inodes, "
				"shoulda found %d\n",
				tifree, cgp->cg_cs.cs_nifree);
#endif
	}
#endif

	return 0;
}

#ifdef CLEAR_FREE_INODES
/*
 * Simplified from fsck/pass1.c checkinode
 */
static int
inodeisfree(int32_t magic, union dinode *dp)
{
	static union dinode zino;

	switch (magic) {
	case FS_UFS1_MAGIC:
		if (dp->dp1.di_mode != 0 || dp->dp1.di_size != 0 ||
		    memcmp(dp->dp1.di_db, zino.dp1.di_db,
			   NDADDR * sizeof(ufs1_daddr_t)) ||
		    memcmp(dp->dp1.di_ib, zino.dp1.di_ib,
			   NIADDR * sizeof(ufs1_daddr_t)))
			return 0;
		break;
	case FS_UFS2_MAGIC:
		if (dp->dp2.di_mode != 0 || dp->dp2.di_size != 0 ||
		    memcmp(dp->dp2.di_db, zino.dp2.di_db,
			   NDADDR * sizeof(ufs2_daddr_t)) ||
		    memcmp(dp->dp2.di_ib, zino.dp2.di_ib,
			   NIADDR * sizeof(ufs2_daddr_t))) {
			fprintf(stderr, "mode=%x, size=%x\n", 
				dp->dp2.di_mode, (unsigned)dp->dp2.di_size);
			return 0;
		}
		break;
	}

	return 1;
}

static void
inodefixup(void *bstart, off_t bsize, void *fdata)
{
	uint32_t magic = *(uint32_t *)fdata;
	void *ptr, *eptr;
	int inodesize;

	switch (magic) {
	case FS_UFS1_MAGIC:
		inodesize = sizeof(struct ufs1_dinode);
		break;
	case FS_UFS2_MAGIC:
		inodesize = sizeof(struct ufs2_dinode);
		break;
	default:
		fprintf(stderr, "Unknown UFS version: %x\n", magic);
		exit(1);
	}
	assert((bsize % inodesize) == 0);

	if (debug > 1)
		fprintf(stderr, "inodefixup: %d UFS%d inodes\n",
			(int)(bsize / inodesize),
			magic == FS_UFS2_MAGIC ? 2 : 1);

	for (ptr = bstart, eptr = ptr+bsize; ptr < eptr; ptr += inodesize) {
		uint32_t gen;

		if (!inodeisfree(magic, (union dinode *)ptr)) {
			fprintf(stderr, "UFS%d inode is not free!\n",
				magic == FS_UFS1_MAGIC ? 1 : 2);
			exit(1);
		}
		/*
		 * Save off the randomized generation number
		 * and zap the rest.
		 */
		gen = DIP(magic, (union dinode *)ptr, di_gen);
		memset(ptr, 0, inodesize);
		if (magic == FS_UFS1_MAGIC)
			((union dinode *)ptr)->dp1.di_gen = gen;
		else
			((union dinode *)ptr)->dp2.di_gen = gen;
	}
}
#endif
