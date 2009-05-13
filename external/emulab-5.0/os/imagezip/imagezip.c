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

/*
 * An image zipper.
 *
 * TODO:
 *	Multithread so that we can be reading ahead on the input device
 *	and overlapping IO with compression.  Maybe a third thread for
 *	doing output.
 */
#include <ctype.h>
#include <err.h>
#include <fcntl.h>
#include <fstab.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <string.h>
#include <assert.h>
#include <errno.h>
#include <sys/param.h>
#include <sys/time.h>
#include <sys/stat.h>
#include <zlib.h>

#include "imagehdr.h"
#include "sliceinfo.h"
#include "global.h"

#define min(a,b) ((a) <= (b) ? (a) : (b))

char	*infilename;
int	infd, outfd, outcanseek;
int	secsize	  = 512;	/* XXX bytes. */
int	debug	  = 0;
int	dots	  = 0;
int     info      = 0;
int     version   = 0;
int     slicemode = 0;
int     maxmode   = 0;
int     slice     = 0;
int	level	  = 4;
long	dev_bsize = 1;
int	oldstyle  = 0;
int	frangesize= 64;	/* 32k */
int	forcereads= 0;
int	badsectors= 0;
int	retrywrites= 1;
int	dorelocs  = 1;
int	metaoptimize = 0;
off_t	datawritten;
partmap_t ignore, forceraw;

#ifdef WITH_SHD
char	*chkpointdev;
#endif

#ifdef WITH_HASH
char	*hashfile;
#endif

#define HDRUSED(reg, rel) \
    (sizeof(blockhdr_t) + \
    (reg) * sizeof(struct region) + (rel) * sizeof(struct blockreloc))

/*
 * We want to be able to compress slices by themselves, so we need
 * to know where the slice starts when reading the input file for
 * compression. 
 *
 * These numbers are in sectors.
 */
extern unsigned long getdisksize(int fd);
unsigned long inputminsec	= 0;
unsigned long inputmaxsec	= 0;	/* 0 means the entire input image */

/*
 * A list of data ranges. 
 */
struct range {
	uint32_t	start;		/* In sectors */
	uint32_t	size;		/* In sectors */
	void		*data;
	struct range	*next;
};
struct range	*ranges, *skips, *fixups;
int		numranges, numskips;
struct blockreloc	*relocs;
int			numregions, numrelocs;

void	dumpskips(int verbose);
void	sortrange(struct range *head, int domerge,
		  int (*rangecmp)(struct range *, struct range *));
int	mergeskips(int verbose);
int	mergeranges(struct range *head);
void    makeranges(void);
void	freeranges(struct range *);
void	dumpranges(int verbose);
void	dumpfixups(int verbose);
void	addvalid(uint32_t start, uint32_t size);
void	addreloc(off_t offset, off_t size, int reloctype);
static int cmpfixups(struct range *r1, struct range *r2);
static int read_doslabel(int infd, int lsect, int pstart,
			 struct doslabel *label);

/* Forward decls */
int	read_image(u_int32_t start, int pstart, u_int32_t extstart);
int	read_raw(void);
int	compress_image(void);
void	usage(void);

#ifdef WITH_SHD
int	read_shd(char *shddev, char *infile, int infd, u_int32_t ssect,
		 void (*add)(uint32_t, uint32_t));
#endif

#ifdef WITH_HASH
struct range *hashmap_compute_delta(struct range *, char *, int, u_int32_t);
void	report_hash_stats(int pnum);
#endif

static SLICEMAP_PROCESS_PROTO(read_slice);

struct slicemap fsmap[] = {
	{ DOSPTYP_UNUSED,	"UNUSED",	0 },
#ifdef WITH_FFS
	{ DOSPTYP_386BSD,	"FreeBSD FFS",	read_bsdslice },
	{ DOSPTYP_OPENBSD,	"OpenBSD FFS",	read_bsdslice },
#endif
#ifdef WITH_EXTFS
	{ DOSPTYP_LINUX,	"Linux EXT",	read_linuxslice },
	{ DOSPTYP_LINSWP,	"Linux SWP",	read_linuxswap },
#endif
#ifdef WITH_NTFS
	{ DOSPTYP_NTFS,		"NTFS",		read_ntfsslice },
#endif
#ifdef WITH_FAT
	{ DOSPTYP_FAT12,	"FAT12",	read_fatslice },
	{ DOSPTYP_FAT16,	"FAT16",	read_fatslice },
	{ DOSPTYP_FAT16L,	"FAT16L",	read_fatslice },
	{ DOSPTYP_FAT16L_LBA,	"FAT16 LBA",	read_fatslice },
	{ DOSPTYP_FAT32,	"FAT32",	read_fatslice },
	{ DOSPTYP_FAT32_LBA,	"FAT32 LBA",	read_fatslice },
#endif
	{ DOSPTYP_EXT,		"DOSEXT",	0 },
	{ DOSPTYP_EXT_LBA,	"DOSEXT LBA",	0 },
	{ -1,			"",		0 },
};

static __inline struct slicemap *
getslicemap(int stype)
{
	struct slicemap *smap;

	for (smap = fsmap; smap->type != -1; smap++)
		if (smap->type == stype)
			return smap;
	return 0;
}

#define READ_RETRIES	1
#define WRITE_RETRIES	10

ssize_t
slowread(int fd, void *buf, size_t nbytes, off_t startoffset)
{
	int cc, i, count;

	fprintf(stderr, "read failed: will retry by sector %d more times\n",
		READ_RETRIES);
	
	count = 0;
	for (i = 0; i < READ_RETRIES; i++) {
		if (lseek(fd, startoffset, SEEK_SET) < 0) {
			perror("devread: seeking to set file ptr");
			exit(1);
		}
		while (nbytes > 0) {
			cc = read(fd, buf, nbytes);
			if (cc == 0) {
				nbytes = 0;
				continue;
			}
			if (cc > 0) {
				nbytes -= cc;
				buf     = (void *)((char *)buf + cc);
				count  += cc;
				continue;
			}

			nbytes += count;
			buf     = (void *)((char *)buf - count);
			count   = 0;
			break;
		}
		if (nbytes == 0)
			break;
	}
	return count;
}

/*
 * Assert the hell out of it...
 */
off_t
devlseek(int fd, off_t off, int whence)
{
	off_t noff;
	assert((off & (DEV_BSIZE-1)) == 0);
	noff = lseek(fd, off, whence);
	assert(noff == (off_t)-1 || (noff & (DEV_BSIZE-1)) == 0);
	return noff;
}

/*
 * Wrap up read in a retry mechanism to persist in the face of IO errors,
 * even faking data if requested.
 */
ssize_t
devread(int fd, void *buf, size_t nbytes)
{
	int		cc, count;
	off_t		startoffset;
	size_t		onbytes;

#ifndef linux
	assert((nbytes & (DEV_BSIZE-1)) == 0);
#endif
	cc = read(fd, buf, nbytes);
	if (!forcereads || cc >= 0)
		return cc;

	/*
	 * Got an error reading the range.
	 * Retry one sector at a time, replacing any bad sectors with
	 * zeroed data.
	 */
	if ((startoffset = lseek(fd, (off_t) 0, SEEK_CUR)) < 0) {
		perror("devread: seeking to get input file ptr");
		exit(1);
	}
	assert((startoffset & (DEV_BSIZE-1)) == 0);

	onbytes = nbytes;
	while (nbytes > 0) {
		if (nbytes > DEV_BSIZE)
			count = DEV_BSIZE;
		else
			count = nbytes;
		cc = slowread(fd, buf, count, startoffset);
		if (cc != count) {
			fprintf(stderr, "devread: read failed on sector %u, "
				"returning zeros\n",
				bytestosec(startoffset));
			if (cc < 0)
				cc = 0;
			memset(buf, 0, count-cc);
			badsectors++;
			cc = count;
		}
		nbytes -= cc;
		buf = (void *)((char *)buf + cc);
		startoffset += cc;
	}
	return onbytes;
}

/*
 * Wrap up write in a retry mechanism to protect against transient NFS
 * errors causing a fatal error. 
 */
ssize_t
devwrite(int fd, const void *buf, size_t nbytes)
{
	int		cc, i, count = 0;
	off_t		startoffset = 0;

	if (retrywrites && outcanseek &&
	    ((startoffset = lseek(fd, (off_t) 0, SEEK_CUR)) < 0)) {
		perror("devwrite: seeking to get output file ptr");
		exit(1);
	}

	for (i = 0; i < WRITE_RETRIES; i++) {
		while (nbytes) {
			cc = write(fd, buf, nbytes);

			if (cc > 0) {
				nbytes -= cc;
				buf     = (void *)((char *)buf + cc);
				count  += cc;
				continue;
			}

			if (!retrywrites)
				return cc;

			if (i == 0) 
				perror("write error: will retry");
	
			sleep(1);
			nbytes += count;
			buf     = (void *)((char *)buf - count);
			count   = 0;
			goto again;
		}
		if (retrywrites && fsync(fd) < 0) {
			perror("fsync error: will retry");
			sleep(1);
			nbytes += count;
			buf     = (void *)((char *)buf - count);
			count   = 0;
			goto again;
		}
		datawritten += count;
		return count;
	again:
		if (lseek(fd, startoffset, SEEK_SET) < 0) {
			perror("devwrite: seeking to set file ptr");
			exit(1);
		}
	}
	perror("write error: busted for too long");
	fflush(stderr);
	exit(1);
}

static int
setpartition(partmap_t map, char *str)
{
	int dospart;
	char bsdpart;

	if (isdigit(str[1])) {
		bsdpart = str[2];
		str[2] = '\0';
	} else {
		bsdpart = str[1];
		str[1] = '\0';
	}
	dospart = atoi(str);
	if (dospart < 1 || dospart > MAXSLICES)
		return EINVAL;

	/* common case: apply to complete DOS partition */
	if (bsdpart == '\0') {
		map[dospart-1] = ~0;
		return 0;
	}

	if (bsdpart < 'a' || bsdpart > 'p')
		return EINVAL;

	map[dospart-1] |= (1 << (bsdpart - 'a'));
	return 0;
}

int
main(int argc, char *argv[])
{
	int	ch, rval;
	char	*outfilename = 0;
	int	rawmode	  = 0;
	int	slicetype = 0;
	struct timeval sstamp;
	extern char build_info[];

	gettimeofday(&sstamp, 0);
	while ((ch = getopt(argc, argv, "vlbnNdihrs:c:z:oI:1F:DR:S:XC:H:M")) != -1)
		switch(ch) {
		case 'v':
			version++;
			break;
		case 'i':
			info++;
			debug++;
			break;
		case 'D':
			retrywrites = 0;
			break;
		case 'd':
			debug++;
			break;
		case 'l':
			slicetype = DOSPTYP_LINUX;
			break;
		case 'b':
			slicetype = DOSPTYP_386BSD;
			break;
		case 'N':
			dorelocs = 0;
			break;
		case 'n':
			slicetype = DOSPTYP_NTFS;
			break;
		case 'o':
			dots++;
			break;
		case 'r':
			rawmode++;
			break;
		case 'S':
			slicetype = atoi(optarg);
			break;
		case 's':
			slicemode = 1;
			slice = atoi(optarg);
			break;
		case 'z':
			level = atoi(optarg);
			if (level < 0 || level > 9)
				usage();
			break;
		case 'c':
			maxmode     = 1;
			inputmaxsec = atoi(optarg);
			break;
		case 'I':
			if (setpartition(ignore, optarg))
				usage();
			break;
		case 'R':
			if (setpartition(forceraw, optarg))
				usage();
			break;
		case '1':
			oldstyle = 1;
			break;
		case 'F':
			frangesize = atoi(optarg);
			if (frangesize < 0)
				usage();
			break;
		case 'X':
			forcereads++;
			break;
		case 'C':
#ifdef WITH_SHD
			chkpointdev = optarg;
#else
			fprintf(stderr, "'C' option not supported\n");
			usage();
#endif
			break;
		case 'H':
#ifdef WITH_HASH
			hashfile = optarg;
#else
			fprintf(stderr, "'H' option not supported\n");
			usage();
#endif
			break;
		case 'M':
			metaoptimize++;
			break;
		case 'h':
		case '?':
		default:
			usage();
		}
	argc -= optind;
	argv += optind;

	if (version || debug) {
		fprintf(stderr, "%s\n", build_info);
		if (version) {
			fprintf(stderr, "Supports");
			for (ch = 1; fsmap[ch].type != -1; ch++)
				if (fsmap[ch].process != 0)
					fprintf(stderr, "%c %s",
						ch > 1 ? ',' : ':',
						fsmap[ch].desc);
#ifdef WITH_SHD
			fprintf(stderr, ", SHD device");
#endif
#ifdef WITH_HASH
			fprintf(stderr, ", hash-signature comparison");
#endif
			fprintf(stderr, "\n");
			exit(0);
		}
	}

	if (argc < 1 || argc > 2)
		usage();

	if (slicemode && (slice < 1 || slice > MAXSLICES)) {
		fprintf(stderr, "Slice must be a DOS partition (1-4) "
			"or extended DOS partition (5-%d)\n\n", MAXSLICES);
		usage();
	}
	if (maxmode && slicemode) {
		fprintf(stderr, "Count option (-c) cannot be used with "
			"the slice (-s) option\n\n");
		usage();
	}
	if (!info && argc != 2) {
		fprintf(stderr, "Must specify an output filename!\n\n");
		usage();
	}
	else
		outfilename = argv[1];

	if (!slicemode && dorelocs)
		dorelocs = 0;

	infilename = argv[0];
	if ((infd = open(infilename, O_RDONLY, 0)) < 0) {
		perror(infilename);
		exit(1);
	}

#if 0
	/*
	 * Use OS-specific techniques to discover the size of the disk.
	 * Note that this could produce an image that will not fit on a
	 * smaller disk, as imagezip will consider any space beyond the
	 * final partition as allocated and will record the ranges.
	 */
	if (!slicemode && !maxmode)
		inputmaxsec = getdisksize(infd);
#endif

#ifdef WITH_SHD
	if (chkpointdev) {
		rval = 0;
		if (dorelocs) {
			fprintf(stderr, "WARNING: no relocation info "
				"generated for checkpoint images\n");
			dorelocs = 0;
		}

		/*
		 * Slice indicates the slice shadowed for checkpointing.
		 * XXX we need this right now to determine the offset of
		 * the block numbers returned by the shd device.
		 */
		if (slicemode) {
			struct doslabel doslabel;

			rval = read_doslabel(infd, DOSBBSECTOR, 0, &doslabel);
			if (rval == 0) {
				inputminsec = doslabel.parts[slice-1].dp_start;
				inputmaxsec = inputminsec + 
					doslabel.parts[slice-1].dp_size;
			}
		}

		if (rval == 0) {
			rval = read_shd(chkpointdev, infilename, infd,
					inputminsec, addvalid);
			if (rval == 0)
				sortrange(ranges, 1, 0);
		}
		if (rval) {
			fprintf(stderr, "* * * Aborting * * *\n");
			exit(1);
		}
	} else
#endif
	{
		/*
		 * Create the skip list by scanning the filesystems on
		 * the disk or indicated partition.
		 */
		if (slicetype != 0) {
			rval = read_slice(-1, slicetype, 0, 0,
					  infilename, infd);
			if (rval == -1)
				fprintf(stderr, ", cannot process\n");
		} else if (rawmode)
			rval = read_raw();
		else
			rval = read_image(DOSBBSECTOR, 0, 0);
		if (rval) {
			fprintf(stderr, "* * * Aborting * * *\n");
			exit(1);
		}

		/*
		 * Create a valid range list from the skip list
		 */
		(void) mergeskips(debug > 1);
		if (debug)
			dumpskips(debug > 1);
		makeranges();
	}
	if (debug)
		dumpranges(debug > 1);

	sortrange(fixups, 0, cmpfixups);
	if (debug > 1)
		dumpfixups(debug > 2);
	fflush(stderr);

#ifdef WITH_HASH
	/*
	 * If we are creating a "delta" image from a hash signature,
	 * we read in the signature info and reconcile that with the
	 * known allocated range that we have just computed.  The result
	 * is a new list of ranges that are currently allocated and that
	 * have changed from the signature version.
	 */
	if (hashfile != NULL) {
		struct range *nranges;

		/*
		 * next compare allocated 'ranges' and 'hinfo' to find out the
		 * changed blocks -- computing the hashes for some 'ranges'
		 * in the process
		 */
		nranges = hashmap_compute_delta(ranges, hashfile, infd,
						inputminsec);
		if (nranges == NULL)
			fprintf(stderr, "NO differences !!!!\n");

		freeranges(ranges);
		ranges = nranges;

		if (debug) {
			fprintf(stderr, "\nAfter delta computation: ");
			dumpranges(debug > 1);
		}
		report_hash_stats(slice);
	}
#endif

	/*
	 * Now we have all the allocated information, create the image
	 * (unless we just want an info report).
	 */
	if (!info) {
		if (strcmp(outfilename, "-")) {
			if ((outfd = open(outfilename, O_RDWR|O_CREAT|O_TRUNC,
					  0666)) < 0) {
				perror("opening output file");
				exit(1);
			}
			outcanseek = 1;
		}
		else {
			outfd = fileno(stdout);
			outcanseek = 0;
			retrywrites = 0;
		}
		compress_image();
		assert(fixups == NULL);
	
		if (outcanseek)
			close(outfd);
	}
	close(infd);

	{
		struct timeval stamp;
		unsigned int ms;

		gettimeofday(&stamp, 0);
		if (stamp.tv_usec < sstamp.tv_usec) {
			stamp.tv_usec += 1000000;
			stamp.tv_sec--;
		}
		ms = (stamp.tv_sec - sstamp.tv_sec) * 1000 +
			(stamp.tv_usec - sstamp.tv_usec) / 1000;
		fprintf(stderr,
			"Finished in %u.%03u seconds\n",
			ms / 1000, ms % 1000);
	}
	fflush(stderr);

	exit(0);
}

static int
read_slice(int snum, int stype, u_int32_t start, u_int32_t size,
	   char *sname, int sfd)
{
	struct slicemap *smap = getslicemap(stype);

	if (smap && smap->process)
		return (*smap->process)(snum, stype, start, size, sname, sfd);
	
	fprintf(stderr, "Slice %d is an unknown type %#x (%s)",
		snum+1, stype, smap ? smap->desc : "??");
	return -1;
}

/*
 * Read a DOS partition table at the indicated offset.
 * If successful return 0 with *label filled in.  Otherwise return an error.
 */
static int
read_doslabel(int infd, int lsect, int pstart, struct doslabel *label)
{
	int cc;

	if (devlseek(infd, sectobytes(lsect), SEEK_SET) < 0) {
		warn("Could not seek to DOS label at sector %u", lsect);
		return 1;
	}
	if ((cc = devread(infd, label->pad2, DOSPARTSIZE)) < 0) {
		warn("Could not read DOS label at sector %u", lsect);
		return 1;
	}
	if (cc != DOSPARTSIZE) {
		warnx("Incomplete read of DOS label at sector %u", lsect);
 		return 1;
	}
	if (label->magic != BOOT_MAGIC) {
		warnx("Wrong magic number in DOS partition table at sector %u",
		      lsect);
 		return 1;
	}

	if (debug) {
		int i;

		if (lsect == DOSBBSECTOR)
			fprintf(stderr, "DOS Partitions:\n");
		else
			fprintf(stderr,
				"DOS Partitions in Extended table at %u\n",
				lsect);
		for (i = 0; i < NDOSPART; i++) {
			struct slicemap *smap;
			u_int32_t start;
			int bsdix = pstart + i;

			fprintf(stderr, "  P%d: ", bsdix + 1);
			smap = getslicemap(label->parts[i].dp_typ);
			if (smap == 0)
				fprintf(stderr, "%-10s", "UNKNOWN");
			else
				fprintf(stderr, "%-10s", smap->desc);

			start = label->parts[i].dp_start;
#if 0
			/* Make start sector absolute */
			if (ISEXT(label->parts[i].dp_typ))
				start += extstart;
			else
				start += bbstart;
#endif
			fprintf(stderr, "  start %9d, size %9d\n",
				start, label->parts[i].dp_size);
		}
		fprintf(stderr, "\n");
	}

	return 0;
}

/*
 * Parse the DOS partition table and dispatch to the individual readers.
 */
int
read_image(u_int32_t bbstart, int pstart, u_int32_t extstart)
{
	int		i, rval = 0;
	struct slicemap	*smap;
	struct doslabel doslabel;

	if (read_doslabel(infd, bbstart, pstart, &doslabel) != 0)
		return 1;

	/*
	 * Now operate on individual slices. 
	 */
	for (i = 0; i < NDOSPART; i++) {
		unsigned char	type  = doslabel.parts[i].dp_typ;
		u_int32_t	start = bbstart + doslabel.parts[i].dp_start;
		u_int32_t	size  = doslabel.parts[i].dp_size;
		int		bsdix = pstart + i;

		if (slicemode && bsdix + 1 != slice && !ISEXT(type))
			continue;
		
		if (ignore[bsdix]) {
			if (!ISBSD(type) || ignore[bsdix] == ~0)
				type = DOSPTYP_UNUSED;
		} else if (forceraw[bsdix]) {
			if (!ISBSD(type) || forceraw[bsdix] == ~0) {
				fprintf(stderr,
					"  Slice %d, forcing raw compression\n",
					bsdix + 1);
				goto skipcheck;
			}
		}

		smap = getslicemap(type);
		switch (type) {
		case DOSPTYP_EXT:
		case DOSPTYP_EXT_LBA:
			/*
			 * XXX extended partition start sectors are
			 * relative to the first extended partition found
			 */
			rval = read_image(extstart + doslabel.parts[i].dp_start,
					  pstart + NDOSPART,
					  extstart ? extstart : start);
			/* XXX for inputmaxsec calculation below */
			start = extstart + doslabel.parts[i].dp_start;
			break;

		case DOSPTYP_UNUSED:
			fprintf(stderr,
				"  Slice %d %s, NOT SAVING.\n", bsdix + 1,
				ignore[bsdix] ? "ignored" : "is unused");
			if (size > 0)
				addskip(start, size);
			break;

		default:
			rval = read_slice(bsdix, type, start, size,
					  infilename, infd);
			if (rval == -1) {
				fprintf(stderr, ", forcing raw compression\n");
				rval = 0;
			}
			break;
		}
		if (rval) {
			if (!ISEXT(type))
				fprintf(stderr,
					"  Filesystem specific error "
					"in Slice %d, "
					"use -R%d to force raw compression.\n",
					bsdix + 1, bsdix + 1);
			break;
		}
		
	skipcheck:
		/*
		 * In slicemode, we need to set the bounds of compression.
		 * Slice is a DOS partition number (1-4). If not in slicemode,
		 * we cannot set the bounds according to the doslabel since its
		 * possible that someone will create a disk with empty space
		 * before the first partition (typical, to start partition 1
		 * at the second cylinder) or after the last partition (Mike!).
		 * However, do not set the inputminsec since we usually want the
		 * stuff before the first partition, which is the boot stuff.
		 */
		if (slicemode && slice == bsdix + 1) {
			inputminsec = start;
			inputmaxsec = start + size;
		} else if (!slicemode && !maxmode) {
			if (start + size > inputmaxsec)
				inputmaxsec = start + size;
		}
	}

	return rval;
}


/*
 * For a raw image (something we know nothing about), we report the size
 * and compress the entire thing (that is, there are no skip ranges).
 */
int
read_raw(void)
{
	off_t	size;

	if ((size = devlseek(infd, (off_t) 0, SEEK_END)) < 0) {
		warn("lseeking to end of raw image");
		return 1;
	}

	if (debug) {
		fprintf(stderr, "  Raw Image\n");
		fprintf(stderr, "        start %12d, size %12lld\n", 0, size);
	}
	return 0;
}

char *usagestr = 
 "usage: imagezip [-vihor] [-s #] <image | device> [outputfilename]\n"
 " -v             Print version info and exit\n"
 " -i             Info mode only.  Do not write an output file\n"
 " -h             Print this help message\n"
 " -o             Print progress indicating dots\n"
 " -r             Generate a `raw' image.  No FS compression is attempted\n"
 " -s slice       Compress a particular slice (DOS numbering 1-4)\n"
 " image | device The input image or a device special file (ie: /dev/ad0)\n"
 " outputfilename The output file ('-' for stdout)\n"
 "\n"
 " Advanced options\n"
 " -z level       Set the compression level.  Range 0-9 (0==none, default==4)\n"
 " -I slice       Ignore (skip) the indicated slice (not with slice mode)\n"
 " -R slice       Force raw compression of the indicated slice (not with slice mode)\n"
 " -c count       Compress <count> number of sectors (not with slice mode)\n"
 " -D             Do `dangerous' writes (don't check for async errors)\n"
 " -1             Output a version one image file\n"
 " -H hashfile    Use the specified imagehash-generated signature to produce a delta image\n"
 "\n"
 " Debugging options (not to be used by mere mortals!)\n"
 " -d             Turn on debugging.  Multiple -d options increase output\n"
 " -b             FreeBSD slice only.  Input must be a FreeBSD FFS slice\n"
 " -l             Linux slice only.  Input must be a Linux EXT2FS slice\n"
 " -n             NTFS slice only.  Input must be an NTFS slice\n"
 " -S DOS-ptype   Treat the input device as containing a slice of the given type\n";

void
usage()
{
	fprintf(stderr, usagestr);
	exit(1);
}

/*
 * Add a range of free space to skip
 */
void
addskip(uint32_t start, uint32_t size)
{
	struct range	   *skip;

	if ((skip = (struct range *) malloc(sizeof(*skip))) == NULL) {
		fprintf(stderr, "No memory for skip range, "
			"try again with '-F <numsect>'\n"
			"where <numsect> is greater than the current %d\n",
			frangesize);
		exit(1);
	}
	
	skip->start = start;
	skip->size  = size;
	skip->next  = skips;
	skips       = skip;
	numskips++;
}

/*
 * Add an explicit valid block range.
 * We always add entries to the end of the list since we are commonly
 * called with alredy sorted entries.
 */
void
addvalid(uint32_t start, uint32_t size)
{
	static struct range **lastvalid = &ranges;
	struct range *valid;

	if ((valid = (struct range *) malloc(sizeof(*valid))) == NULL) {
		fprintf(stderr, "No memory for valid range\n");
		exit(1);
	}
	
	valid->start = start;
	valid->size  = size;
	valid->next  = 0;
	*lastvalid   = valid;
	lastvalid    = &valid->next;
	numranges++;
}

void
dumpskips(int verbose)
{
	struct range	*pskip;
	uint32_t	offset = 0, total = 0;
	int		nranges = 0;

	if (!skips)
		return;

	if (verbose) {
		fprintf(stderr, "\nMin sector %lu, Max sector %lu\n",
			inputminsec, inputmaxsec);
		fprintf(stderr, "Skip ranges (start/size) in sectors:\n");
	}

	pskip = skips;
	while (pskip) {
		if (verbose)
			fprintf(stderr,
				"  %12d    %9d\n", pskip->start, pskip->size);
		assert(pskip->start >= offset);
		offset = pskip->start + pskip->size;
		total += pskip->size;
		nranges++;
		pskip  = pskip->next;
	}
	
	fprintf(stderr,
		"Total Number of Free Sectors: %d (bytes %lld) in %d ranges\n",
		total, sectobytes(total), nranges);
}

#undef DOHISTO

/*
 * Sort and merge the list of skip blocks.
 * This code also winnows out the free ranges smaller than frangesize.
 * Returns the number of entries freed, useful so that it can be called
 * on-the-fly if we run out of memory to see if we managed to free anything.
 */
int
mergeskips(int verbose)
{
	struct range *prange, **prevp;
	int freed = 0, culled = 0;
	uint32_t total = 0;
#ifdef DOHISTO
	uint32_t histo[64];
	memset(histo, 0, sizeof(histo));
#endif

	sortrange(skips, 0, 0);
	freed += mergeranges(skips);

	/*
	 * After merging, make another pass to cull out the too-small ranges.
	 */
	if (frangesize) {
		prevp = &skips;
		while (*prevp) {
			prange = *prevp;
			if (prange->size < (uint32_t)frangesize) {
				if (debug > 2)
					fprintf(stderr,
						"dropping range [%u-%u]\n",
						prange->start,
						prange->start+prange->size-1);
				total += prange->size;
#ifdef DOHISTO
				if (prange->size < 64)
					histo[prange->size]++;
#endif
				*prevp = prange->next;
				free(prange);
				culled++;
			} else
				prevp = &prange->next;
		}
		if (verbose && culled) {
			fprintf(stderr,
				"\nFree Sectors Ignored: %d (%lld bytes) in %d ranges\n",
				total, sectobytes(total), culled);
#ifdef DOHISTO
			{
				int i;
				double r, s;
				double cumr = 0.0, cums = 0.0;
				for (i = 0; i < 64; i++) {
					if (histo[i] == 0)
						continue;
					r = (double)histo[i]/culled*100.0;
					cumr += r;
					s = (double)(histo[i]*i)/total*100.0;
					cums += s;
					fprintf(stderr,
						"%d: %u, %4.1f%% (%4.1f%%) of ranges "
						"%4.1f%% (%4.1f%%) of sectors)\n",
						i, histo[i], r, cumr, s, cums);
				}
			}
#endif
		}
	}

	return (freed + culled);
}

/*
 * A very dumb bubblesort!
 */
void
sortrange(struct range *head, int domerge,
	  int (*rangecmp)(struct range *, struct range *))
{
	struct range	*prange, tmp;
	int		changed = 1;

	if (head == NULL)
		return;
	
	while (changed) {
		changed = 0;

		prange = head;
		while (prange) {
			if (prange->next &&
			    (prange->start > prange->next->start ||
			     (rangecmp && (*rangecmp)(prange, prange->next)))) {
				tmp.start = prange->start;
				tmp.size  = prange->size;
				tmp.data  = prange->data;

				prange->start = prange->next->start;
				prange->size  = prange->next->size;
				prange->data  = prange->next->data;
				prange->next->start = tmp.start;
				prange->next->size  = tmp.size;
				prange->next->data  = tmp.data;

				changed = 1;
			}
			prange  = prange->next;
		}
	}

	if (domerge)
		(void)mergeranges(head);

	return;
}

/*
 * Look for contiguous free regions and combine them.
 * Returns the number of entries freed up as a result of merging.
 */
int
mergeranges(struct range *head)
{
	struct range *prange, *ptmp;
	int freed = 0;

	prange = head;
	while (prange) {
		if (prange->next == 0)
			break;

		if (prange->start + prange->size == prange->next->start) {
			if (debug > 2)
				fprintf(stderr,
					"merging ranges [%u-%u] and [%u-%u]\n",
					prange->start,
					prange->start+prange->size-1,
					prange->next->start,
					prange->next->start+prange->next->size-1);
			prange->size += prange->next->size;
			
			ptmp = prange->next;
			prange->next = ptmp->next;
			free(ptmp);
			freed++;
		} else
			prange = prange->next;
	}

	return (freed);
}

/*
 * Life is easier if I think in terms of the valid ranges instead of
 * the free ranges. So, convert them.  Note that if there were no skips,
 * we create a single range covering the entire partition.
 */
void
makeranges(void)
{
	struct range	*pskip, *ptmp;
	uint32_t	offset;
	
	offset = inputminsec;

	pskip = skips;
	while (pskip) {
		addvalid(offset, pskip->start - offset);
		offset = pskip->start + pskip->size;
		
		ptmp  = pskip;
		pskip = pskip->next;
		free(ptmp);
	}
	/*
	 * Last piece, but only if there is something to compress.
	 */
	if (inputmaxsec == 0 || (inputmaxsec - offset) != 0) {
		assert(inputmaxsec == 0 || inputmaxsec > offset);

		/*
		 * A bug in FreeBSD causes lseek on a device special file to
		 * return 0 all the time! Well we want to be able to read
		 * directly out of a raw disk (/dev/ad0), so we need to
		 * use the compressor to figure out the actual size when it
		 * isn't known beforehand.
		 *
		 * Mark the last range with 0 so compression goes to end
		 * if we don't know where it is.
		 */
		addvalid(offset, inputmaxsec ? (inputmaxsec - offset) : 0);
	}
}

void
freeranges(struct range *head)
{
	struct range *next;

	while (head != NULL) {
		next = head->next;
		free(head);
		head = next;
	}
}

void
dumpranges(int verbose)
{
	struct range *range;
	uint32_t total = 0;
	int nranges = 0;

	if (verbose)
		fprintf(stderr, "\nAllocated ranges (start/size) in sectors:\n");
	range = ranges;
	while (range) {
		if (verbose)
			fprintf(stderr, "  %12d    %9d\n",
				range->start, range->size);
		total += range->size;
		nranges++;
		range = range->next;
	}
	fprintf(stderr,
		"Total Number of Valid Sectors: %d (bytes %lld) in %d ranges\n",
		total, sectobytes(total), nranges);
}

/*
 * Fixup descriptor handling.
 *
 * Fixups are modifications that need to be made to file data prior
 * to compressing.
 */
struct fixup {
	off_t offset;	/* disk offset */
	off_t poffset;	/* partition offset */
	off_t size;
	int reloctype;
	void *data;	/* current value of data ptr */
	void (*func)(void *, off_t, void *);
};
static int nfixups;

static void
addfixupentry(off_t offset, off_t poffset, off_t size, void *data, off_t dsize,
	      int reloctype, void (*func)(void *, off_t, void *))
{
	struct mydata {
		struct fixup _fixup;
		char _fdata[0];
	} *buf;
	struct range *entry;
	struct fixup *fixup;
	void *fdata;

	if (oldstyle) {
		static int warned;

		if (!warned) {
			fprintf(stderr, "WARNING: no fixups in V1 images\n");
			warned = 1;
		}
		return;
	}

	/*
	 * Malloc the range separate from the fixup data since
	 * sortranges will swap contents of the former.
	 */
	if ((entry = malloc(sizeof(*entry))) == NULL ||
	    (buf = malloc(sizeof(*buf) + (size_t)dsize)) == NULL) {
		fprintf(stderr, "Out of memory!\n");
		exit(1);
	}
	assert((void *)buf == (void *)&buf->_fixup);

	fixup = &buf->_fixup;
	fdata = dsize ? buf->_fdata : NULL;
	
	entry->start = bytestosec(offset);
	entry->size  = bytestosec(size + secsize - 1);
	entry->data  = fixup;
	
	fixup->offset    = offset;
	fixup->poffset   = poffset;
	fixup->size      = size;
	fixup->reloctype = reloctype;
	fixup->data	 = fdata;
	if (fdata)
		memcpy(fixup->data, data, (size_t)dsize);
	fixup->func	 = func;

	entry->next  = fixups;
	fixups       = entry;
	nfixups++;
}

/*
 * Create a fixup to apply to the disk data prior to compressing.
 * The given fixup will be applied to the appropriate data and a relocation
 * genearated if desired.  The region over which the fixup should be
 * applied is given by 'offset' and 'size'.  That range is replaced by
 * the data in 'data'.  If 'reloctype' is not 0, a relocation entry of
 * the appropraite type is generated.  'poffset' is the partition
 * offset which is used when generating relocations to ensure that
 * they are partition-relative.
 */
void
addfixup(off_t offset, off_t poffset, off_t size, void *data, int reloctype)
{
	addfixupentry(offset, poffset, size, data, size, reloctype, NULL);
}

/*
 * Similar to the above but calls a function with the fixup entry and the
 * range of data to apply the fixup to.  The data arg is passed to the
 * function along with the data range.
 */
void
addfixupfunc(void (*func)(void *, off_t, void *), off_t offset,
	     off_t poffset, off_t size, void *data, int dsize, int reloctype)
{
	addfixupentry(offset, poffset, size, data, dsize, reloctype, func);
}

/*
 * Return 1 if r1 > r2
 */
static int
cmpfixups(struct range *r1, struct range *r2)
{
	if (r1->start > r2->start ||
	    (r1->start == r2->start &&
	     ((struct fixup *)r1->data)->offset >
	     ((struct fixup *)r2->data)->offset))
		return 1;
	return 0;
}

/*
 * See if there is a fixup associated with any part of the given addr range.
 * Returns 1 if so, 0 otherwise.
 */
int
hasfixup(uint32_t soffset, uint32_t ssize)
{
	struct range *rp;
	struct fixup *fp;
	off_t offset, eoffset;

	offset = sectobytes(soffset);
	eoffset = offset + sectobytes(ssize);
	for (rp = fixups; rp != NULL; rp = rp->next) {
		fp = rp->data;

		/* range completely before fixup, all done */
		if (eoffset <= fp->offset)
			break;

		/* range completely after fixup, keep looking */
		if (offset >= fp->offset + fp->size)
			continue;

		/* otherwise, there is overlap */
#ifdef FOLLOW
		fprintf(stderr, "R: [%u-%u] overlaps with F: [%u/%u-%u/%u]\n",
			soffset, soffset+ssize-1,
			bytestosec(fp->offset),
			(uint32_t)fp->offset % SECSIZE,
			bytestosec(fp->offset+fp->size-1),
			(uint32_t)(fp->offset+fp->size-1) % SECSIZE);
#endif
		return 1;
	}

	return 0;
}

/*
 * Look for fixups which overlap the range [offset - offset+size-1].
 * If an overlap is found, we overwrite the data for that range with
 * that given in the fixup or call the associated function.
 */
void
applyfixups(off_t offset, off_t size, void *data)
{
	struct range **prev, *entry;
	struct fixup *fp;
	uint32_t coff, clen;

#ifdef FOLLOW
	fprintf(stderr, "D: [%u-%u], %d fixups\n",
		bytestosec(offset), bytestosec(offset+size)-1, nfixups);
#endif
	prev = &fixups;
	while ((entry = *prev) != NULL) {
		assert(entry->data != NULL);
		fp = entry->data;
#ifdef FOLLOW
		fprintf(stderr, "  F%p: [%u/%u-%u/%u]: ",
			fp,
			bytestosec(fp->offset),
			(uint32_t)fp->offset % SECSIZE,
			bytestosec(fp->offset+fp->size-1),
			(uint32_t)(fp->offset+fp->size-1) % SECSIZE);
#endif

		/*
		 * Since we sort both the ranges we are processing and
		 * the fixup ranges, and we remove fixups as we apply them,
		 * we should never encounter any fixups that fall even
		 * partially before the data range we are operating on.
		 */
		assert(fp->offset >= offset);

		/*
		 * Again, since the lists are sorted, if the current fixup
		 * starts beyond the end of the data we are processing,
		 * we are done.
		 */
		if (offset+size <= fp->offset) {
#ifdef FOLLOW
			fprintf(stderr, "falls after, done\n");
#endif
			break;
		}

		/*
		 * If the frange extends beyond the current data buffer,
		 * apply as much as we can and save the rest.  We only do
		 * this for RELOC_NONE for the moment.
		 */
		if (fp->offset+fp->size > offset+size) {
			assert(fp->reloctype == RELOC_NONE);
			coff = (u_int32_t)(fp->offset - offset);
			clen = (offset + size) - fp->offset;
		} else {
			coff = (u_int32_t)(fp->offset - offset);
			clen = (u_int32_t)fp->size;
		}
		assert(offset+coff == fp->offset);
		assert(offset+coff+clen <= fp->offset+fp->size);

		if (debug > 2)
			fprintf(stderr,
				"Applying %sfixup [%llu-%llu] to [%llu-%llu]\n",
				(clen == (u_int32_t)fp->size) ?
				"full " : "partial ",
				fp->offset, fp->offset+fp->size,
				offset, offset+size);

		/* don't mess with data arg for functions */
		if (fp->func != NULL)
			(*fp->func)(data+coff, (off_t)clen, fp->data);
		else {
			memcpy(data+coff, fp->data, clen);
			fp->data += clen;
		}

		/* create a reloc if necessary */
		if (fp->reloctype != RELOC_NONE)
			addreloc(fp->offset - fp->poffset,
				 fp->size, fp->reloctype);

		/*
		 * See if there is anything left over in the fixup.
		 * If so, adjust it and move to the next entry.
		 * If not, free the entry.
		 */
		fp->size -= clen;
		if (fp->size > 0) {
			fp->offset += clen;
#ifdef FOLLOW
			fprintf(stderr, "used, reduced to [%u/%u-%u/%u]\n",
				bytestosec(fp->offset),
				(uint32_t)fp->offset % SECSIZE,
				bytestosec(fp->offset+fp->size-1),
				(uint32_t)(fp->offset+fp->size-1) % SECSIZE);
#endif
			prev = &entry->next;
		} else {
#ifdef FOLLOW
			fprintf(stderr, "used, freed E%p\n", entry);
#endif
			*prev = entry->next;
			free(entry->data);
			free(entry);
			nfixups--;
			if (debug > 2)
				fprintf(stderr, " %d fixups left\n",
					nfixups);
		}
	}
}

void
dumpfixups(int verbose)
{
	struct range *range;
	struct fixup *fp;
	int nfixups = 0;

	if (verbose)
		fprintf(stderr, "\nFixups (start/size) in sectors and bytes:\n");
	range = fixups;
	while (range) {
		assert(range->data != NULL);
		fp = range->data;

		if (verbose) {
			fprintf(stderr, "  %12d    %9d (%12lld/%9lld)\n",
				range->start, range->size,
				fp->offset, fp->size);
		}
		nfixups++;
		range = range->next;
	}
	fprintf(stderr, "Total Number of Fixups: %d\n", nfixups);
}

void
addreloc(off_t offset, off_t size, int reloctype)
{
	struct blockreloc *reloc;

	assert(!oldstyle);

	numrelocs++;
	if (HDRUSED(numregions, numrelocs) > DEFAULTREGIONSIZE) {
		fprintf(stderr, "Over filled region/reloc table (%d/%d)\n",
			numregions, numrelocs);
		exit(1);
	}

	relocs = realloc(relocs, numrelocs * sizeof(struct blockreloc));
	if (relocs == NULL) {
		fprintf(stderr, "Out of memory!\n");
		exit(1);
	}

	reloc = &relocs[numrelocs-1];
	reloc->type = reloctype;
	reloc->sector = bytestosec(offset);
	reloc->sectoff = offset - sectobytes(reloc->sector);
	reloc->size = size;
}

void
freerelocs(void)
{
	numrelocs = 0;
	free(relocs);
	relocs = NULL;
}

/*
 * Compress the image.
 */
static uint8_t  output_buffer[SUBBLOCKSIZE];
static int	buffer_offset;
static off_t	inputoffset;
static struct timeval cstamp;
static long long bytescompressed;

static off_t	compress_chunk(off_t, off_t, int *, uint32_t *);
static int	compress_finish(uint32_t *subblksize);
static void	compress_status(int sig);

/*
 * Loop through the image, compressing the allocated ranges.
 */
int
compress_image(void)
{
	int		cc, full, i, count, chunkno;
	off_t		size = 0, outputoffset;
	off_t		tmpoffset, rangesize;
	struct range	*prange;
	blockhdr_t	*blkhdr;
	struct region	*curregion, *regions;
	struct timeval  estamp;
	uint8_t		*buf;
	uint32_t	cursect = 0;
	struct region	*lreg;

	gettimeofday(&cstamp, 0);
	inputoffset = 0;
#ifdef SIGINFO
	signal(SIGINFO, compress_status);
#endif

	buf = output_buffer;
	memset(buf, 0, DEFAULTREGIONSIZE);
	blkhdr = (blockhdr_t *) buf;
	if (oldstyle)
		regions = (struct region *)((struct blockhdr_V1 *)blkhdr + 1);
	else
		regions = (struct region *)(blkhdr + 1);
	curregion = regions;
	numregions = 0;
	chunkno = 0;

	/*
	 * Reserve room for the subblock hdr and the region pairs.
	 * We go back and fill it it later after the subblock is
	 * done and we know much input data was compressed into
	 * the block.
	 */
	buffer_offset = DEFAULTREGIONSIZE;
	
	prange = ranges;
	while (prange) {
		inputoffset = sectobytes(prange->start);

		/*
		 * Seek to the beginning of the data range to compress.
		 */
		devlseek(infd, (off_t) inputoffset, SEEK_SET);

		/*
		 * The amount to compress is the size of the range, which
		 * might be zero if its the last one (size unknown).
		 */
		rangesize = sectobytes(prange->size);

		/*
		 * Compress the chunk.
		 */
		if (debug > 1 && debug < 3) {
			fprintf(stderr,
				"Compressing range: %14lld --> ", inputoffset);
			fflush(stderr);
		}

		size = compress_chunk(inputoffset, rangesize,
				      &full, &blkhdr->size);
	
		if (debug > 2) {
			fprintf(stderr, "%14lld -> %12lld %10ld %10u %10d %d\n",
				inputoffset, inputoffset + size,
				prange->start - inputminsec,
				bytestosec(size),
				blkhdr->size, full);
		}
		else if (debug > 1) {
			gettimeofday(&estamp, 0);
			estamp.tv_sec -= cstamp.tv_sec;
			fprintf(stderr, "%12lld in %ld seconds.\n",
				inputoffset + size, estamp.tv_sec);
		}
		else if (dots && full) {
			static int pos;

			putc('.', stderr);
			if (pos++ >= 60) {
				gettimeofday(&estamp, 0);
				estamp.tv_sec -= cstamp.tv_sec;
				fprintf(stderr, " %12lld %4ld\n",
					inputoffset+size, estamp.tv_sec);
				pos = 0;
			}
			fflush(stderr);
		}

		if (size == 0)
			goto done;

		/*
		 * This should never happen!
		 */
		if (size & (secsize - 1)) {
			fprintf(stderr, "  Not on a sector boundry at %lld\n",
				inputoffset);
			return 1;
		}

		/*
		 * We have completed a region.  We have either:
		 *
		 * 1. compressed the entire current input range
		 * 2. run out of room in the 1MB chunk
		 * 3. hit the end of the input file
		 *
		 * For #1 we want to continue filling the current chunk.
		 * For 2 and 3 we are done with the current chunk.
		 */
		curregion->start = prange->start - inputminsec;
		curregion->size  = bytestosec(size);
		curregion++;
		numregions++;

		/*
		 * Check to see if the region/reloc table is full.
		 * If this is the last region that will fit in the available
		 * space (i.e., one more would not), finish off any
		 * compression we are in the middle of and declare the
		 * region full.
		 */
		if (HDRUSED(numregions+1, numrelocs) > DEFAULTREGIONSIZE) {
			assert(HDRUSED(numregions, numrelocs) <=
			       DEFAULTREGIONSIZE);
			if (!full) {
				compress_finish(&blkhdr->size);
				full = 1;
			}
		}

		/*
		 * 1. We managed to compress the entire range,
		 *    go to the next range continuing to fill the
		 *    current chunk.
		 */
		if (!full) {
			assert(rangesize == 0 || size == rangesize);

			prange = prange->next;
			continue;
		}

		/*
		 * A partial range. Well, maybe a partial range.
		 *
		 * Go back and stick in the block header and the region
		 * information.
		 */
		blkhdr->magic = oldstyle ? COMPRESSED_V1 :
			(!dorelocs ? COMPRESSED_V2 : COMPRESSED_MAGIC_CURRENT);
		blkhdr->blockindex  = chunkno;
		blkhdr->regionsize  = DEFAULTREGIONSIZE;
		blkhdr->regioncount = (curregion - regions);
		if (!oldstyle) {
			blkhdr->firstsect   = cursect;
			if (size == rangesize) {
				/*
				 * Finished subblock at the end of a range.
				 * Find the beginning of the next range so that
				 * we include any free space between the ranges
				 * here.  If this was the last range, we use
				 * inputmaxsec.  If inputmaxsec is zero, we know
				 * that we did not end with a skip range.
				 */
				if (prange->next)
					blkhdr->lastsect = prange->next->start -
						inputminsec;
				else if (inputmaxsec > 0)
					blkhdr->lastsect = inputmaxsec -
						inputminsec;
				else {
					lreg = curregion - 1;
					blkhdr->lastsect =
						lreg->start + lreg->size;
				}
			} else {
				lreg = curregion - 1;
				blkhdr->lastsect = lreg->start + lreg->size;
			}
			cursect = blkhdr->lastsect;

			blkhdr->reloccount = numrelocs;
		}

		/*
		 * Dump relocation info
		 */
		if (numrelocs) {
			assert(!oldstyle);
			assert(relocs != NULL);
			memcpy(curregion, relocs,
			       numrelocs * sizeof(struct blockreloc));
			freerelocs();
		}

		/*
		 * Write out the finished chunk to disk.
		 */
		cc = devwrite(outfd, output_buffer, sizeof(output_buffer));
		if (cc != sizeof(output_buffer)) {
			if (cc < 0)
				perror("chunk write");
			else
				fprintf(stderr,
					"chunk write: short write (%d bytes)\n",
					cc);
			exit(1);
		}

		/*
		 * Moving to the next block. Reserve the header area.
		 */
		memset(buf, 0, DEFAULTREGIONSIZE);
		buffer_offset = DEFAULTREGIONSIZE;
		curregion     = regions;
		numregions    = 0;
		chunkno++;

		/*
		 * Okay, so its possible that we ended the region at the
		 * end of the subblock. I guess "partial" is a bad name.
		 * Anyway, most of the time we ended a subblock in the
		 * middle of a range, and we have to keeping going on it.
		 *
		 * Ah, the last range is a possible special case. It might
		 * have a 0 size if we were reading from a device special
		 * file that does not return the size from lseek (Freebsd).
		 * Zero indicated that we just read until EOF cause we have
		 * no idea how big it really is.
		 */
		if (size == rangesize) 
			prange = prange->next;
		else {
			uint32_t sectors = bytestosec(size);
			
			prange->start += sectors;
			if (prange->size)
				prange->size -= sectors;
		}
	}

 done:
	/*
	 * Have to finish up by writing out the last batch of region info.
	 */
	if (curregion != regions) {
		compress_finish(&blkhdr->size);
		
		blkhdr->magic = oldstyle ? COMPRESSED_V1 :
			(!dorelocs ? COMPRESSED_V2 : COMPRESSED_MAGIC_CURRENT);
		blkhdr->blockindex  = chunkno;
		blkhdr->regionsize  = DEFAULTREGIONSIZE;
		blkhdr->regioncount = (curregion - regions);
		if (!oldstyle) {
			blkhdr->firstsect = cursect;
			if (inputmaxsec > 0)
				blkhdr->lastsect = inputmaxsec - inputminsec;
			else {
				lreg = curregion - 1;
				blkhdr->lastsect = lreg->start + lreg->size;
			}
			blkhdr->reloccount = numrelocs;
		}

		/*
		 * Check to see if the region/reloc table is full.
		 * XXX handle this gracefully sometime.
		 */
		if (HDRUSED(numregions, numrelocs) > DEFAULTREGIONSIZE) {
			fprintf(stderr, "Over filled region table (%d/%d)\n",
				numregions, numrelocs);
			exit(1);
		}

		/*
		 * Dump relocation info
		 */
		if (numrelocs) {
			assert(!oldstyle);
			assert(relocs != NULL);
			memcpy(curregion, relocs,
			       numrelocs * sizeof(struct blockreloc));
			freerelocs();
		}

		/*
		 * Write out the finished chunk to disk, and
		 * start over from the beginning of the buffer.
		 */
		cc = devwrite(outfd, output_buffer, sizeof(output_buffer));
		if (cc != sizeof(output_buffer)) {
			if (cc < 0)
				perror("chunk write");
			else
				fprintf(stderr,
					"chunk write: short write (%d bytes)\n",
					cc);
			exit(1);
		}
		buffer_offset = 0;
	}

	inputoffset += size;
	if (debug > 1 || dots)
		fprintf(stderr, "\n");
	compress_status(0);
	fflush(stderr);

	/*
	 * For version 2 we don't bother to go back and fill in the
	 * blockcount.  Imageunzip and frisbee don't use it.  We still
	 * do it if creating V1 images and we can seek on the output.
	 */
	if (!oldstyle || !outcanseek)
		return 0;
	
	/*
	 * Get the total filesize, and then number the subblocks.
	 * Useful, for netdisk.
	 */
	if ((tmpoffset = lseek(outfd, (off_t) 0, SEEK_END)) < 0) {
		perror("seeking to get output file size");
		exit(1);
	}
	count = tmpoffset / SUBBLOCKSIZE;

	for (i = 0, outputoffset = 0; i < count;
	     i++, outputoffset += SUBBLOCKSIZE) {
		
		if (lseek(outfd, (off_t) outputoffset, SEEK_SET) < 0) {
			perror("seeking to read block header");
			exit(1);
		}
		if ((cc = read(outfd, buf, sizeof(blockhdr_t))) < 0) {
			perror("reading subblock header");
			exit(1);
		}
		assert(cc == sizeof(blockhdr_t));
		if (lseek(outfd, (off_t) outputoffset, SEEK_SET) < 0) {
			perror("seeking to write new block header");
			exit(1);
		}
		blkhdr = (blockhdr_t *) buf;
		assert(blkhdr->blockindex == i);
		blkhdr->blocktotal = count;
		
		if ((cc = devwrite(outfd, buf, sizeof(blockhdr_t))) < 0) {
			perror("writing new subblock header");
			exit(1);
		}
		assert(cc == sizeof(blockhdr_t));
	}
	return 0;
}

static void
compress_status(int sig)
{
	struct timeval stamp;
	int oerrno = errno;
	unsigned int ms, bps;

	gettimeofday(&stamp, 0);
	if (stamp.tv_usec < cstamp.tv_usec) {
		stamp.tv_usec += 1000000;
		stamp.tv_sec--;
	}
	ms = (stamp.tv_sec - cstamp.tv_sec) * 1000 +
		(stamp.tv_usec - cstamp.tv_usec) / 1000;
	fprintf(stderr,
		"%llu input (%llu compressed) bytes in %u.%03u seconds\n",
		inputoffset, bytescompressed, ms / 1000, ms % 1000);
	if (badsectors)
		fprintf(stderr, "%d bad input sectors skipped\n", badsectors);
	if (sig == 0) {
		fprintf(stderr, "Image size: %llu bytes\n", datawritten);
		bps = (bytescompressed * 1000) / ms;
		fprintf(stderr, "%.3fMB/second compressed\n",
			(double)bps / (1024*1024));
	}
	errno = oerrno;
}

/*
 * Compress a chunk. The next bit of input stream is read in and compressed
 * into the output file. 
 */
#define BSIZE		(128 * 1024)
static char		inbuf[BSIZE];
static			int subblockleft = SUBBLOCKMAX;
static z_stream		d_stream;	/* Compression stream */

#define CHECK_ZLIB_ERR(err, msg) { \
    if (err != Z_OK) { \
        fprintf(stderr, "%s error: %d\n", msg, err); \
        exit(1); \
    } \
}

static off_t
compress_chunk(off_t off, off_t size, int *full, uint32_t *subblksize)
{
	int		cc, count, err, tileof, finish, outsize;
	off_t		total = 0;

	/*
	 * Whenever subblockleft equals SUBBLOCKMAX, it means that a new
	 * compression subblock needs to be started.
	 */
	if (subblockleft == SUBBLOCKMAX) {
		d_stream.zalloc = (alloc_func)0;
		d_stream.zfree  = (free_func)0;
		d_stream.opaque = (voidpf)0;

		err = deflateInit(&d_stream, level);
		CHECK_ZLIB_ERR(err, "deflateInit");
	}
	*full  = 0;
	finish = 0;

	/*
	 * If no size, then we want to compress until the end of file
	 * (and report back how much).
	 */
	if (!size) {
		tileof  = 1;
		size	= BSIZE + 1;
	} else
		tileof  = 0;

	while (size > 0) {
		if (size > BSIZE)
			count = BSIZE;
		else
			count = (int) size;

		/*
		 * As we get near the end of the subblock, reduce the amount
		 * of input to make sure we can fit without producing a
		 * partial output block. Easier. See explanation below.
		 * Also, subtract out a little bit as we get near the end since
		 * as the blocks get smaller, it gets more likely that the
		 * data won't be compressable (maybe its already compressed),
		 * and the output size will be *bigger* than the input size.
		 */
		if (count > (subblockleft - 1024)) {
			count = subblockleft - 1024;

			/*
			 * But of course, we always want to be sector aligned.
			 */
			count = count & ~(secsize - 1);
		}

		cc = devread(infd, inbuf, count);
		if (cc < 0) {
			perror("reading input file");
			exit(1);
		}
		
		if (cc == 0) {
			/*
			 * If hit the end of the file, then finish off
			 * the compression.
			 */
			finish = 1;
			break;
		}

		if (cc != count && !tileof) {
			fprintf(stderr, "Bad count in read, %d != %d at %llu\n",
				cc, count,
				off+total);
			exit(1);
		}

		/*
		 * Apply fixups.  This may produce a relocation record.
		 */
		if (fixups != NULL)
			applyfixups(off+total, count, inbuf);

		if (!tileof)
			size -= cc;
		total += cc;

		outsize = SUBBLOCKSIZE - buffer_offset;

		/* XXX match behavior of original compressor */
		if (oldstyle && outsize > 0x20000)
			outsize = 0x20000;

		d_stream.next_in   = (Bytef *)inbuf;
		d_stream.avail_in  = cc;
		d_stream.next_out  = &output_buffer[buffer_offset];
		d_stream.avail_out = outsize;
		assert(d_stream.avail_out > 0);

		err = deflate(&d_stream, Z_SYNC_FLUSH);
		CHECK_ZLIB_ERR(err, "deflate");

		if (d_stream.avail_in != 0 ||
		    (!oldstyle && d_stream.avail_out == 0)) {
			fprintf(stderr, "Something went wrong, ");
			if (d_stream.avail_in)
				fprintf(stderr, "not all input deflated!\n");
			else
				fprintf(stderr, "too much data for chunk!\n");
			exit(1);
		}
		count = outsize - d_stream.avail_out;
		buffer_offset += count;
		assert(buffer_offset <= SUBBLOCKSIZE);
		bytescompressed += cc - d_stream.avail_in;

		/*
		 * If we have reached the subblock maximum, then need
		 * to start a new compression block. In order to make
		 * this simpler, I do not allow a partial output
		 * buffer to be written to the file. No carryover to the
		 * next block, and thats nice. I also avoid anything
		 * being left in the input buffer. 
		 * 
		 * The downside of course is wasted space, since I have to
		 * quit early to avoid not having enough output space to
		 * compress all the input. How much wasted space is kinda
		 * arbitrary since I can just make the input size smaller and
		 * smaller as you get near the end, but there are diminishing
		 * returns as your write calls get smaller and smaller.
		 * See above where I compare count to subblockleft.
		 */
		subblockleft -= count;
		assert(subblockleft >= 0);
		
		if (subblockleft < 0x2000) {
			finish = 1;
			*full  = 1;
			break;
		}
	}
	if (finish) {
		compress_finish(subblksize);
		return total;
	}
	*subblksize = SUBBLOCKMAX - subblockleft;
	return total;
}

/*
 * Need a hook to finish off the last part and write the pending data.
 */
static int
compress_finish(uint32_t *subblksize)
{
	int		err, count;

	if (subblockleft == SUBBLOCKMAX)
		return 0;
	
	d_stream.next_in   = 0;
	d_stream.avail_in  = 0;
	d_stream.next_out  = &output_buffer[buffer_offset];
	d_stream.avail_out = SUBBLOCKSIZE - buffer_offset;

	err = deflate(&d_stream, Z_FINISH);
	if (err != Z_STREAM_END)
		CHECK_ZLIB_ERR(err, "deflate");

	assert(d_stream.avail_out > 0);

	/*
	 * There can be some left even though we use Z_SYNC_FLUSH!
	 */
	count = (SUBBLOCKSIZE - buffer_offset) - d_stream.avail_out;
	if (count) {
		buffer_offset += count;
		assert(buffer_offset <= SUBBLOCKSIZE);
		subblockleft -= count;
		assert(subblockleft >= 0);
	}

	err = deflateEnd(&d_stream);
	CHECK_ZLIB_ERR(err, "deflateEnd");

	/*
	 * The caller needs to know how big the actual data is.
	 */
	*subblksize  = SUBBLOCKMAX - subblockleft;
		
	/*
	 * Pad the subblock out.
	 */
	assert(buffer_offset + subblockleft <= SUBBLOCKSIZE);
	memset(&output_buffer[buffer_offset], 0, subblockleft);
	buffer_offset += subblockleft;
	subblockleft = SUBBLOCKMAX;
	return 1;
}
