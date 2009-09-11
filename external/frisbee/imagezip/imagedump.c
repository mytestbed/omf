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
 * Usage: imagedump <input file>
 *
 * Prints out information about an image.
 */

#include <stdio.h>
#include <stdlib.h>
#include <fcntl.h>
#include <assert.h>
#include <unistd.h>
#include <string.h>
#include <zlib.h>
#include <sys/stat.h>
#include "imagehdr.h"

static int detail = 0;
static int dumpmap = 0;
static int ignorev1 = 0;
static int infd = -1;

static unsigned long long wasted;
static uint32_t sectinuse;
static uint32_t sectfree;
static uint32_t relocs;
static unsigned long long relocbytes;

static void usage(void);
static void dumpfile(char *name, int fd);
static int dumpchunk(char *name, char *buf, int chunkno, int checkindex);

#define SECTOBYTES(s)	((unsigned long long)(s) * SECSIZE)

int
main(int argc, char **argv)
{
	int ch, version = 0;
	extern char build_info[];

	while ((ch = getopt(argc, argv, "dimv")) != -1)
		switch(ch) {
		case 'd':
			detail++;
			break;
		case 'i':
			ignorev1++;
			break;
		case 'm':
			dumpmap++;
			detail = 0;
			break;
		case 'v':
			version++;
			break;
		case 'h':
		case '?':
		default:
			usage();
		}
	argc -= optind;
	argv += optind;

	if (version || detail) {
		fprintf(stderr, "%s\n", build_info);
		if (version)
			exit(0);
	}

	if (argc < 1)
		usage();

	while (argc > 0) {
		int isstdin = !strcmp(argv[0], "-");

		if (!isstdin) {
			if ((infd = open(argv[0], O_RDONLY, 0666)) < 0) {
				perror("opening input file");
				exit(1);
			}
		} else
			infd = fileno(stdin);

		dumpfile(isstdin ? "<stdin>" : argv[0], infd);

		if (!isstdin)
			close(infd);
		argc--;
		argv++;
	}
	exit(0);
}

static void
usage(void)
{
	fprintf(stderr, "usage: "
		"imagedump options <image filename> ...\n"
		" -v              Print version info and exit\n"
		" -d              Turn on progressive levels of detail\n");
	exit(1);
}	

static char chunkbuf[SUBBLOCKSIZE];
static unsigned int magic;
static unsigned long chunkcount;
static uint32_t nextsector;
static uint32_t fmax, fmin, franges, amax, amin, aranges;
static uint32_t adist[8]; /* <4k, <8k, <16k, <32k, <64k, <128k, <256k, >=256k */

static void
dumpfile(char *name, int fd)
{
	unsigned long long tbytes, dbytes, cbytes;
	int count, chunkno, checkindex = 1;
	off_t filesize;
	int isstdin;
	char *bp;

	isstdin = (fd == fileno(stdin));
	wasted = sectinuse = sectfree = 0;
	nextsector = 0;

	fmax = amax = 0;
	fmin = amin = ~0;
	franges = aranges = 0;
	memset(adist, 0, sizeof(adist));

	if (!isstdin) {
		struct stat st;

		if (fstat(fd, &st) < 0) {
			perror(name);
			return;
		}
		if ((st.st_size % SUBBLOCKSIZE) != 0)
			printf("%s: WARNING: "
			       "file size not a multiple of chunk size\n",
			       name);
		filesize = st.st_size;
	} else
		filesize = 0;

	for (chunkno = 0; ; chunkno++) {
		bp = chunkbuf;

		if (isstdin)
			count = sizeof(chunkbuf);
		else {
			count = DEFAULTREGIONSIZE;
			if (lseek(infd, (off_t)chunkno*sizeof(chunkbuf),
				  SEEK_SET) < 0) {
				perror("seeking on zipped image");
				return;
			}
		}

		/*
		 * Parse the file one chunk at a time.  We read the entire
		 * chunk and hand it off.  Since we might be reading from
		 * stdin, we have to make sure we get the entire amount.
		 */
		while (count) {
			int cc;
			
			if ((cc = read(infd, bp, count)) <= 0) {
				if (cc == 0)
					goto done;
				perror("reading zipped image");
				return;
			}
			count -= cc;
			bp += cc;
		}
		if (chunkno == 0) {
			blockhdr_t *hdr = (blockhdr_t *)chunkbuf;

			magic = hdr->magic;
			if (magic < COMPRESSED_MAGIC_BASE ||
			    magic > COMPRESSED_MAGIC_CURRENT) {
				printf("%s: bad version %x\n", name, magic);
				return;
			}

			if (ignorev1) {
				chunkcount = 0;
				checkindex = 0;
			} else
				chunkcount = hdr->blocktotal;
			if ((filesize / SUBBLOCKSIZE) != chunkcount) {
				if (chunkcount != 0) {
					if (isstdin)
						filesize = (off_t)chunkcount *
							SUBBLOCKSIZE;
					else
						printf("%s: WARNING: file size "
						       "inconsistant with "
						       "chunk count "
						       "(%lu != %lu)\n",
						       name,
						       (unsigned long)
						       (filesize/SUBBLOCKSIZE),
						       chunkcount);
				} else if (magic == COMPRESSED_V1) {
					if (!ignorev1)
						printf("%s: WARNING: "
						       "zero chunk count, "
						       "ignoring block fields\n",
						       name);
					checkindex = 0;
				}
			}

			printf("%s: %qu bytes, %lu chunks, version %d\n",
			       name, filesize,
			       (unsigned long)(filesize / SUBBLOCKSIZE),
			       hdr->magic - COMPRESSED_MAGIC_BASE + 1);
		} else if (chunkno == 1 && !ignorev1) {
			blockhdr_t *hdr = (blockhdr_t *)chunkbuf;

			/*
			 * If reading from stdin, we don't know til the
			 * second chunk whether blockindexes are being kept.
			 */
			if (isstdin && filesize == 0 && hdr->blockindex == 0)
				checkindex = 0;
		}

		if (dumpchunk(name, chunkbuf, chunkno, checkindex))
			break;
	}
 done:
	if (filesize == 0)
		filesize = (off_t)(chunkno + 1) * SUBBLOCKSIZE;

	cbytes = (unsigned long long)(filesize - wasted);
	dbytes = SECTOBYTES(sectinuse);
	tbytes = SECTOBYTES(sectinuse + sectfree);

	if (detail > 0)
		printf("\n");

	printf("  %qu bytes of overhead/wasted space (%5.2f%% of image file)\n",
	       wasted, (double)wasted / filesize * 100);
	if (relocs)
		printf("  %d relocations covering %qu bytes\n",
		       relocs, relocbytes);
	printf("  %qu bytes of compressed data\n",
	       cbytes);
	printf("  %5.2fx compression of allocated data (%qu bytes)\n",
	       (double)dbytes / cbytes, dbytes);
	printf("  %5.2fx compression of total known disk size (%qu bytes)\n",
	       (double)tbytes / cbytes, tbytes);

	if (franges)
		printf("  %d free ranges: %qu/%qu/%qu ave/min/max size\n",
		       franges, SECTOBYTES(sectfree)/franges,
		       SECTOBYTES(fmin), SECTOBYTES(fmax));
	if (aranges) {
		int maxsz, i;

		printf("  %d allocated ranges: %qu/%qu/%qu ave/min/max size\n",
		       aranges, SECTOBYTES(sectinuse)/aranges,
		       SECTOBYTES(amin), SECTOBYTES(amax));
		printf("  size distribution:\n");
		maxsz = 4*SECSIZE;
		for (i = 0; i < 7; i++) {
			maxsz *= 2;
			if (adist[i])
				printf("    < %dk bytes: %d\n",
				       maxsz/1024, adist[i]);
		}
		if (adist[i])
			printf("    >= %dk bytes: %d\n", maxsz/1024, adist[i]);
	}
}

static int
dumpchunk(char *name, char *buf, int chunkno, int checkindex)
{
	blockhdr_t *hdr;
	struct region *reg;
	uint32_t count;
	int i;

	hdr = (blockhdr_t *)buf;

	switch (hdr->magic) {
	case COMPRESSED_V1:
		reg = (struct region *)((struct blockhdr_V1 *)hdr + 1);
		break;
	case COMPRESSED_V2:
	case COMPRESSED_V3:
		reg = (struct region *)((struct blockhdr_V2 *)hdr + 1);
		break;
	default:
		printf("%s: bad magic (%x!=%x) in chunk %d\n",
		       name, hdr->magic, magic, chunkno);
		return 1;
	}
	if (checkindex && hdr->blockindex != chunkno) {
		printf("%s: bad chunk index (%d) in chunk %d\n",
		       name, hdr->blockindex, chunkno);
		return 1;
	}
	if (chunkcount && hdr->blocktotal != chunkcount) {
		printf("%s: bad chunkcount (%d!=%lu) in chunk %d\n",
		       name, hdr->blocktotal, chunkcount, chunkno);
		return 1;
	}
	if (hdr->size > (SUBBLOCKSIZE - hdr->regionsize)) {
		printf("%s: bad chunksize (%d > %d) in chunk %d\n",
		       name, hdr->size, SUBBLOCKSIZE-hdr->regionsize, chunkno);
		return 1;
	}
#if 1
	/* include header overhead */
	wasted += SUBBLOCKSIZE - hdr->size;
#else
	wasted += ((SUBBLOCKSIZE - hdr->regionsize) - hdr->size);
#endif

	if (detail > 0) {
		printf("  Chunk %d: %u compressed bytes, ",
		       chunkno, hdr->size);
		if (hdr->magic > COMPRESSED_V1) {
			printf("sector range [%u-%u], ",
			       hdr->firstsect, hdr->lastsect-1);
			if (hdr->reloccount > 0)
				printf("%d relocs, ", hdr->reloccount);
		}
		printf("%d regions\n", hdr->regioncount);
	}
	if (hdr->regionsize != DEFAULTREGIONSIZE)
		printf("  WARNING: "
		       "unexpected region size (%d!=%d) in chunk %d\n",
		       hdr->regionsize, DEFAULTREGIONSIZE, chunkno);

	for (i = 0; i < hdr->regioncount; i++) {
		if (detail > 1)
			printf("    Region %d: %u sectors [%u-%u]\n",
			       i, reg->size, reg->start,
			       reg->start + reg->size - 1);
		if (reg->start < nextsector)
			printf("    WARNING: chunk %d region %d "
			       "may overlap others\n", chunkno, i);
		if (reg->size == 0)
			printf("    WARNING: chunk %d region %d "
			       "zero-length region\n", chunkno, i);
		count = 0;
		if (hdr->magic > COMPRESSED_V1) {
			if (i == 0) {
				if (hdr->firstsect > reg->start)
					printf("    WARNING: chunk %d bad "
					       "firstsect value (%u>%u)\n",
					       chunkno, hdr->firstsect,
					       reg->start);
				else
					count = reg->start - hdr->firstsect;
			} else
				count = reg->start - nextsector;
			if (i == hdr->regioncount-1) {
				if (hdr->lastsect < reg->start + reg->size)
					printf("    WARNING: chunk %d bad "
					       "lastsect value (%u<%u)\n",
					       chunkno, hdr->lastsect,
					       reg->start + reg->size);
				else {
					if (count > 0) {
						sectfree += count;
						if (count < fmin)
							fmin = count;
						if (count > fmax)
							fmax = count;
						franges++;
					}
					count = hdr->lastsect -
						(reg->start+reg->size);
				}
			}
		} else
			count = reg->start - nextsector;
		if (count > 0) {
			sectfree += count;
			if (count < fmin)
				fmin = count;
			if (count > fmax)
				fmax = count;
			franges++;
		}

		count = reg->size;
		sectinuse += count;
		if (count < amin)
			amin = count;
		if (count > amax)
			amax = count;
		if (count < 8)
			adist[0]++;
		else if (count < 16)
			adist[1]++;
		else if (count < 32)
			adist[2]++;
		else if (count < 64)
			adist[3]++;
		else if (count < 128)
			adist[4]++;
		else if (count < 256)
			adist[5]++;
		else if (count < 512)
			adist[6]++;
		else
			adist[7]++;
		aranges++;

		if (dumpmap) {
			switch (hdr->magic) {
			case COMPRESSED_V1:
				if (reg->start - nextsector != 0)
					printf("F: [%08x-%08x]\n",
					       nextsector, reg->start-1);
				printf("A: [%08x-%08x]\n",
				       reg->start, reg->start + reg->size - 1);
				break;
			case COMPRESSED_V2:
			case COMPRESSED_V3:
				if (i == 0 && hdr->firstsect < reg->start)
					printf("F: [%08x-%08x]\n",
					       hdr->firstsect, reg->start-1);
				if (i != 0 && reg->start - nextsector != 0)
					printf("F: [%08x-%08x]\n",
					       nextsector, reg->start-1);
				printf("A: [%08x-%08x]\n",
				       reg->start, reg->start + reg->size - 1);
				if (i == hdr->regioncount-1 &&
				    reg->start+reg->size < hdr->lastsect)
					printf("F: [%08x-%08x]\n",
					       reg->start+reg->size,
					       hdr->lastsect-1);
				break;
			}
		}

		nextsector = reg->start + reg->size;
		reg++;
	}

	if (hdr->magic == COMPRESSED_V1)
		return 0;

	for (i = 0; i < hdr->reloccount; i++) {
		struct blockreloc *reloc = &((struct blockreloc *)reg)[i];

		relocs++;
		relocbytes += reloc->size;

		if (reloc->sector < hdr->firstsect ||
		    reloc->sector >= hdr->lastsect)
			printf("    WARNING: "
			       "Reloc %d at %u not in chunk [%u-%u]\n", i,
			       reloc->sector, hdr->firstsect, hdr->lastsect-1);
		if (detail > 1) {
			char *relocstr;

			switch (reloc->type) {
			case RELOC_FBSDDISKLABEL:
				relocstr = "FBSDDISKLABEL";
				break;
			case RELOC_OBSDDISKLABEL:
				relocstr = "OBSDDISKLABEL";
				break;
			case RELOC_LILOSADDR:
				relocstr = "LILOSADDR";
				break;
			case RELOC_LILOMAPSECT:
				relocstr = "LILOMAPSECT";
				break;
			case RELOC_LILOCKSUM:
				relocstr = "LILOCKSUM";
				break;
			default:
				relocstr = "??";
				break;
			}
			printf("    Reloc %d: %s sector %d, offset %u-%u\n", i,
			       relocstr, reloc->sector, reloc->sectoff,
			       reloc->sectoff + reloc->size);
		}
	}

	return 0;
}
