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
 * Usage: imagehash
 *
 * Compute the hash signature of an imagezip image or compare a signature
 * to disk contents.
 */

#include <stdio.h>
#include <stdlib.h>
#include <fcntl.h>
#include <assert.h>
#include <unistd.h>
#include <string.h>
#include <zlib.h>
#include <sys/stat.h>
#include <sys/time.h>
#include <errno.h>
#include <openssl/sha.h>
#include <openssl/md5.h>
#ifndef NOTHREADS
#include <pthread.h>
#endif
#ifdef HAVE_STRVIS
#include <vis.h>
#endif

#include "imagehdr.h"
#include "imagehash.h"
#include "queue.h"

#ifndef linux
#define TIMEIT
#endif

#define MAXREADBUFMEM	(8*HASHBLK_SIZE)	/* 0 == unlimited */

typedef struct readbuf {
	queue_chain_t chain;
	struct region region;
	unsigned char data[0];
} readbuf_t;
static unsigned long maxreadbufmem = MAXREADBUFMEM;

static int dovis = 0;
static int doall = 1;
static int detail = 0;
static int create = 0;
static int report = 0;
static int regfile = 0;
static int nothreads = 0;
static int hashtype = HASH_TYPE_SHA1;
static int hashlen = 20;
static long hashblksize = HASHBLK_SIZE;
static unsigned long long ndatabytes;
static unsigned long nchunks, nregions, nhregions;
static char *imagename;
static char *fileid = NULL;
static char *sigfile = NULL;

static char chunkbuf[SUBBLOCKSIZE];

static void usage(void);
static int gethashinfo(char *name, struct hashinfo **hinfo);
static int readhashinfo(char *name, struct hashinfo **hinfop);
static int checkhash(char *name, struct hashinfo *hinfo);
static void dumphash(char *name, struct hashinfo *hinfo);
static int createhash(char *name, struct hashinfo **hinfop);
static int hashimage(char *name, struct hashinfo **hinfop);
static int hashchunk(int chunkno, char *chunkbufp, struct hashinfo **hinfop);
static int hashfile(char *name, struct hashinfo **hinfop);
static int hashfilechunk(int chunkno, char *chunkbufp, int chunksize,
			 struct hashinfo **hinfop);
static char *spewhash(unsigned char *h, int hlen);

static char *signame(char *name);
static int imagecmp(char *ifile, char *dev);
static int datacmp(uint32_t off, uint32_t size, unsigned char *idata);

static int startreader(char *name, struct hashinfo *hinfo);
static void stopreader(void);
static struct readbuf *getblock(struct hashregion *reg);
static void putblock(readbuf_t *rbuf);
static void readblock(readbuf_t *rbuf);
static readbuf_t *alloc_readbuf(uint32_t start, uint32_t size, int dowait);
static void free_readbuf(readbuf_t *rbuf);
static void dump_readbufs(void);
static void dump_stats(int sig);

#define sectobytes(s)	((off_t)(s) * SECSIZE)
#define bytestosec(b)	(uint32_t)((b) / SECSIZE)

int
main(int argc, char **argv)
{
	int ch, version = 0;
	extern char build_info[];
	struct hashinfo *hashinfo = 0;

	while ((ch = getopt(argc, argv, "cb:dvhno:rD:NVRF:")) != -1)
		switch(ch) {
		case 'b':
			hashblksize = atol(optarg);
			if (hashblksize < 512 || hashblksize > (32*1024*1024)) {
				fprintf(stderr, "Invalid hash block size\n");
				usage();
			}
			if (maxreadbufmem < hashblksize)
				maxreadbufmem = hashblksize;
			break;
		case 'F':
			fileid = strdup(optarg);
			break;
		case 'R':
			report++;
		case 'c':
			create++;
			break;
		case 'o':
			sigfile = strdup(optarg);
			break;
		case 'D':
			if (strcmp(optarg, "md5") == 0)
				hashtype = HASH_TYPE_MD5;
			else if (strcmp(optarg, "sha1") == 0)
				hashtype = HASH_TYPE_SHA1;
			else if (strcmp(optarg, "raw") == 0)
				hashtype = HASH_TYPE_RAW;
			else {
				fprintf(stderr, "Invalid digest type `%s'\n",
					optarg);
				usage();
			}
			break;
		case 'd':
			detail++;
			break;
		case 'N':
			doall = 0;
			break;
		case 'n':
			nothreads++;
			break;
		case 'v':
			version++;
			break;
		case 'V':
			dovis = 1;
			break;
		case 'r':
			regfile = 1;
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

	if ((create && argc < 1) || (!create && argc < 2))
		usage();
	imagename = argv[0];

	/*
	 * Ensure we can open both files before we do the expensive stuff.
	 */
	if (strcmp(argv[0], "-") != 0 && access(argv[0], R_OK) != 0) {
		/*
		 * If comparing against a sig file, don't require that
		 * the image exist, only the sig.
		 */
		if (!create && access(signame(argv[0]), R_OK) == 0) {
			fprintf(stderr, "WARNING: image does not exist "
				"but signature does, using signature...\n");
		} else {
			perror("image file");
			exit(1);
		}
	}
	if (!create && access(argv[1], R_OK) != 0) {
		perror("device file");
		exit(1);
	}

#ifdef SIGINFO
	signal(SIGINFO, dump_stats);
#endif

	/*
	 * Raw image comparison
	 */
	if (hashtype == HASH_TYPE_RAW)
		exit(imagecmp(argv[0], argv[1]));

	/*
	 * Create a hash file
	 */
	if (create) {
		if (report) {
			if (fileid == NULL)
				fileid = argv[0];
			hashimage(argv[0], &hashinfo);
		} else {
			if (createhash(argv[0], &hashinfo))
				exit(2);
			dumphash(argv[0], hashinfo);
		}
		exit(0);
	}

	/*
	 * Compare the hash file versus a device
	 */
	if (gethashinfo(argv[0], &hashinfo))
		exit(2);
	dumphash(argv[0], hashinfo);
	(void) checkhash(argv[1], hashinfo);

	exit(0);
}

static void
usage(void)
{
	fprintf(stderr, "usage: "
		"imagehash [-d] <image-filename> <device>\n"
		"    check the signature file for the specified image\n"
		"    against the specified disk device\n"
		"imagehash -c [-dr] [-D hfunc] [-b blksize] [-o sigfile] <image-filename>\n"
		"    create a signature file for the specified image\n"
		"imagehash -R [-dr] [-b blksize] <image-filename>\n"
		"    output an ASCII report to stdout rather than creating a signature file\n"
		"imagehash -v\n"
		"    print version info and exit\n"
		"\n"
		"-D hfunc      hash function to use (md5 or sha1)\n"
		"-b blksize    size of hash blocks (512 <= size <= 32M)\n"
		"-d            print additional detail to STDOUT\n"
		"-o sigfile    name to use for sig file, else <image>.sig\n"
		"-r            input file is a regular file, not an image\n");
	exit(1);
}	

/*
 * Create the signature file name
 */
static char *
signame(char *name)
{
	char *hfile;

	if (sigfile != NULL)
		return sigfile;

	hfile = malloc(strlen(name) + 5);
	if (hfile == NULL) {
		fprintf(stderr, "%s: out of memory\n", name);
		exit(2);
	}
	strcpy(hfile, name);
	strcpy(hfile + strlen(hfile), ".sig");

	return hfile;
}

/*
 * If the image file has a signature, read that.
 * Otherwise, parse the image file to extract the information.
 */
static int
gethashinfo(char *name, struct hashinfo **hinfop)
{
	if (strcmp(name, "-") != 0) {
		if (readhashinfo(name, hinfop) == 0)
			return 0;
		fprintf(stderr,
			"%s: no valid signature, using image file instead...\n",
			name);
	}
	
	return hashimage(name, hinfop);
}

static int
readhashinfo(char *name, struct hashinfo **hinfop)
{
	struct hashinfo hi, *hinfo;
	char *hname;
	int fd, nregbytes, cc;

	hname = signame(name);
	fd = open(hname, O_RDONLY, 0666);
	if (fd < 0) {
		perror(hname);
		free(hname);
		return -1;
	}
	cc = read(fd, &hi, sizeof(hi));
	if (cc != sizeof(hi)) {
	readbad:
		if (cc < 0)
			perror(hname);
		else
			fprintf(stderr, "%s: too short\n", hname);
	bad:
		close(fd);
		free(hname);
		return -1;
	}
	if (strcmp((char *)hi.magic, HASH_MAGIC) != 0 ||
	    hi.version != HASH_VERSION) {
		fprintf(stderr, "%s: not a valid signature file\n", hname);
		goto bad;
	}
	nregbytes = hi.nregions * sizeof(struct hashregion);
	hinfo = malloc(sizeof(hi) + nregbytes);
	if (hinfo == 0) {
		fprintf(stderr, "%s: not enough memory for info\n", hname);
		goto bad;
	}
	*hinfo = hi;
	cc = read(fd, hinfo->regions, nregbytes);
	if (cc != nregbytes) {
		free(hinfo);
		goto readbad;
	}

	close(fd);
	free(hname);
	*hinfop = hinfo;
	switch (hinfo->hashtype) {
	case HASH_TYPE_MD5:
	default:
		hashlen = 16;
		break;
	case HASH_TYPE_SHA1:
		hashlen = 20;
		break;
	}
	nhregions = hinfo->nregions;
	return 0;
}

/*
 * We realloc the region array in big chunks so we don't thrash so much.
 * This is the number of ~32 byte regions per memory chunk
 */
#define REGPERBLK	8192	/* ~256KB -- must be power of 2 */

static void
addhash(struct hashinfo **hinfop, int chunkno, uint32_t start, uint32_t size,
	unsigned char hash[HASH_MAXSIZE])
{
	struct hashinfo *hinfo = *hinfop;
	int nreg;

	if (report) {
		static int first = 1;
		printf("%s\t%u\t%u\t%u\tU\t%s\n",
		       spewhash(hash, hashlen), start, size, chunkno,
		       first ? fileid : "-");
		first = 0;
		return;
	}

	if (hinfo == 0) {
		nreg = 0;
		hinfo = calloc(1, sizeof(*hinfo));
	} else {
		nreg = hinfo->nregions;
	}
	if ((nreg % REGPERBLK) == 0) {
		hinfo = realloc(hinfo, sizeof(*hinfo) +
				(nreg+REGPERBLK) * sizeof(struct hashregion));
		if (hinfo == 0) {
			fprintf(stderr, "out of memory for hash map\n");
			exit(1);
		}
		*hinfop = hinfo;
	}

	hinfo->regions[nreg].chunkno = chunkno;
	hinfo->regions[nreg].region.start = start;
	hinfo->regions[nreg].region.size = size;
	memcpy(hinfo->regions[nreg].hash, hash, HASH_MAXSIZE);
	hinfo->nregions++;
	nhregions = hinfo->nregions;
}

static void
dumphash(char *name, struct hashinfo *hinfo)
{
	uint32_t i;
	struct hashregion *reg;

	if (detail > 1) {
		for (i = 0; i < hinfo->nregions; i++) {
			reg = &hinfo->regions[i];
			printf("[%u-%u]: chunk %d, hash %s\n",
			       reg->region.start,
			       reg->region.start + reg->region.size-1,
			       reg->chunkno, spewhash(reg->hash, hashlen));
		}
	}
}

static char *
spewhash(unsigned char *h, int hlen)
{
	static char hbuf[HASH_MAXSIZE*2+1];
	static const char hex[] = "0123456789abcdef";
	int i;

	for (i = 0; i < hlen; i++) {
		hbuf[i*2] = hex[h[i] >> 4];
		hbuf[i*2+1] = hex[h[i] & 0xf];
	}
	hbuf[i*2] = '\0';
	return hbuf;
}

#ifdef TIMEIT
#include <machine/cpufunc.h>
static u_int64_t rcycles, hcycles, ccycles, dcycles;
#endif

static int
createhash(char *name, struct hashinfo **hinfop)
{
	char *hfile;
	int ofd, cc;
	int count;
	struct hashinfo *hinfo;
	struct stat sb;
	struct timeval tm[2];

	hfile = signame(name);
	ofd = open(hfile, O_RDWR|O_CREAT|O_TRUNC, 0666);
	if (ofd < 0) {
		perror(hfile);
		free(hfile);
		return -1;
	}

	/*
	 * Hash the image file
	 */
	if (hashimage(name, hinfop)) {
		free(hfile);
		return -1;
	}

	/*
	 * Write the image file
	 */
	hinfo = *hinfop;
	strcpy((char *)hinfo->magic, HASH_MAGIC);
	hinfo->version = HASH_VERSION;
	hinfo->hashtype = hashtype;
	count = sizeof(*hinfo) + hinfo->nregions*sizeof(struct hashregion);
	cc = write(ofd, hinfo, count);
	close(ofd);
	if (cc != count) {
		if (cc < 0)
			perror(hfile);
		else
			fprintf(stderr,
				"%s: incomplete write (%d)\n", hfile, cc);
		free(hfile);
		return -1;
	}

	/*
	 * Set the modtime of the hash file to match that of the image.
	 * This is a crude (but fast!) method for matching images with
	 * signatures.
	 */
	cc = stat(name, &sb);
	if (cc >= 0) {
#ifdef linux
		tm[0].tv_sec = sb.st_atime;
		tm[0].tv_usec = 0;
		tm[1].tv_sec = sb.st_mtime;
		tm[1].tv_usec = 0;
#else
		TIMESPEC_TO_TIMEVAL(&tm[0], &sb.st_atimespec);
		TIMESPEC_TO_TIMEVAL(&tm[1], &sb.st_mtimespec);
#endif
		cc = utimes(hfile, tm);
	}
	if (cc < 0)
		fprintf(stderr, "%s: WARNING: could not set mtime (%s)\n",
			hfile, strerror(errno));

	dump_stats(0);
#ifdef TIMEIT
	printf("%qu bytes: inflate cycles: %llu\n", ndatabytes, dcycles);
#endif
	free(hfile);
	return 0;
}

static volatile uint32_t badhashes, checkedhashes;

static int
checkhash(char *name, struct hashinfo *hinfo)
{
	uint32_t i, inbad, badstart, badsize, reportbad;
	uint32_t badchunks, lastbadchunk;
	uint64_t badhashdata;
	struct hashregion *reg;
	int chunkno;
	unsigned char hash[HASH_MAXSIZE];
	unsigned char *(*hashfunc)(const unsigned char *, unsigned long,
				   unsigned char *);
	char *hashstr;
	readbuf_t *rbuf;
	size_t size;
#ifdef TIMEIT
	u_int64_t sstamp, estamp;
#endif

	if (startreader(name, hinfo))
		return -1;

	chunkno = lastbadchunk = -1;
	badhashes = badchunks = inbad = reportbad = 0;
	badhashdata = 0;
	badstart = badsize = ~0;
	switch (hinfo->hashtype) {
	case HASH_TYPE_MD5:
	default:
		hashlen = 16;
		hashfunc = MD5;
		hashstr = "MD5 digest";
		break;
	case HASH_TYPE_SHA1:
		hashlen = 20;
		hashfunc = SHA1;
		hashstr = "SHA1 digest";
		break;
	}
	fprintf(stderr, "Checking disk contents using %s\n", hashstr);

	for (i = 0, reg = hinfo->regions; i < hinfo->nregions; i++, reg++) {
		if (chunkno != reg->chunkno) {
			nchunks++;
			chunkno = reg->chunkno;
		}
		size = sectobytes(reg->region.size);
		rbuf = getblock(reg);
#ifdef TIMEIT
		sstamp = rdtsc();
#endif
		(void)(*hashfunc)(rbuf->data, size, hash);
#ifdef TIMEIT
		estamp = rdtsc();
		hcycles += (estamp - sstamp);
#endif
		putblock(rbuf);
		ndatabytes += size;

		if (detail > 2) {
			printf("[%u-%u]:\n", reg->region.start,
			       reg->region.start + reg->region.size - 1);
			printf("  sig  %s\n", spewhash(reg->hash, hashlen));
			printf("  disk %s\n", spewhash(hash, hashlen));
		}

		if (memcmp(reg->hash, hash, hashlen) == 0) {
			/*
			 * Hash is good.
			 * If we were in a bad stretch, be sure to dump info
			 */
			if (inbad)
				reportbad = 1;
		} else {
			/*
			 * Hash is bad.
			 * If not already in a bad stretch, start one.
			 * If in a bad stretch, lengthen it if contig.
			 * Otherwise, dump the info.
			 */
			badhashes++;
			if (chunkno != lastbadchunk) {
				badchunks++;
				lastbadchunk = chunkno;
			}
			badhashdata += size;
			if (!inbad) {
				inbad = 1;
				badstart = reg->region.start;
				badsize = reg->region.size;
			} else {
				if (badstart + badsize == reg->region.start)
					badsize += reg->region.size;
				else
					reportbad = 1;
			}
		}
#ifdef TIMEIT
		sstamp = rdtsc();
		ccycles += (sstamp - estamp);
#endif
		/*
		 * Report on a bad stretch
		 */
		if (reportbad) {
			if (detail)
				fprintf(stderr, "%s: bad hash for sectors [%u-%u]\n",
					name, badstart, badstart + badsize - 1);
			reportbad = inbad = 0;
		}
		checkedhashes++;
	}
	/*
	 * Finished on a sour note, report the final bad stretch.
	 */
	if (inbad && detail)
		fprintf(stderr, "%s: bad hash for sectors [%u-%u]\n",
			name, badstart, badstart + badsize - 1);

	stopreader();

	dump_stats(0);
	if (badhashes)
		printf("%s: %u regions (%d chunks) had bad hashes, "
		       "%llu bytes affected\n",
		       name, badhashes, badchunks, badhashdata);
	dump_readbufs();
#ifdef TIMEIT
	printf("%llu bytes: read cycles: %llu, hash cycles: %llu, cmp cycles: %llu\n",
	       ndatabytes, rcycles, hcycles, ccycles);
#endif
	return 0;
}

static int
imagecmp(char *ifile, char *dev)
{
	int errors;

#ifndef NOTHREADS
	nothreads = 1;
#endif
	if (startreader(dev, 0))
		return -1;
	errors = hashimage(ifile, 0);
	stopreader();
	return errors;
}

static void
hexdump(unsigned char *p, int nchar)
{
#ifdef HAVE_STRVIS
	if (dovis) {
		char *visbuf = malloc(nchar * 4 + 1);
		if (visbuf)
			strvisx(visbuf, p, nchar, VIS_NL);
		fprintf(stderr, "%s", visbuf);
		free(visbuf);
	} else
#endif
	{
		while (nchar--)
			fprintf(stderr, "%02x", *p++);
	}
}

static struct blockreloc *relocptr;
static int reloccount;

static void
setrelocs(struct blockreloc *reloc, int nrelocs)
{
	relocptr = reloc;
	reloccount = nrelocs;
}

/*
 * Return 1 if data region overlaps with a relocation
 */
static struct blockreloc *
hasrelocs(off_t start, off_t size)
{
	off_t rstart, rend;
	struct blockreloc *reloc = relocptr;
	int nrelocs = reloccount;

	while (nrelocs--) {
		if (reloc->type < 1 || reloc->type > 5) {
			fprintf(stderr, "bad reloc: type=%d\n", reloc->type);
			relocptr = 0;
			reloccount = 0;
			break;
		}
		rstart = sectobytes(reloc->sector) + reloc->sectoff;
		rend = rstart + reloc->size;
		if (rend > start && rstart < start + size)
			return reloc;
		reloc++;
	}
	return 0;
}

static void
fullcmp(void *p1, void *p2, off_t sz, uint32_t soff)
{
	unsigned char *ip, *dp;
	off_t off, boff, byoff;
	struct blockreloc *reloc;

	byoff = sectobytes(soff);
	ip = (unsigned char *)p1;
	dp = (unsigned char *)p2;
	off = 0;
	boff = -1;
	while (off < sz) {
		if (ip[off] == dp[off]) {
			if (boff != -1 &&
			    off+1 < sz && ip[off+1] == dp[off+1]) {
				fprintf(stderr, " [%llu-%llu] (sect %u): bad",
					byoff+boff, byoff+off-1, soff);
				reloc = hasrelocs(byoff+boff, off-boff);
				if (reloc)
					fprintf(stderr, " (overlaps reloc [%llu-%llu])",
						sectobytes(reloc->sector)+reloc->sectoff,
						sectobytes(reloc->sector)+reloc->sectoff+reloc->size-1);
				fprintf(stderr, "\n");
				if (detail > 1) {
					fprintf(stderr, "  image: ");
					hexdump(ip+boff, off-boff);
					fprintf(stderr, "\n  disk : ");
					hexdump(dp+boff, off-boff);
					fprintf(stderr, "\n");
				}
				boff = -1;
			}
		} else {
			if (boff == -1)
				boff = off;
		}
		off++;
	}
	if (boff != -1) {
		fprintf(stderr, " [%llu-%llu] bad", byoff+boff, byoff+off-1);
		reloc = hasrelocs(byoff+boff, off-boff);
		if (reloc)
			fprintf(stderr, " (overlaps reloc [%llu-%llu])",
				sectobytes(reloc->sector)+reloc->sectoff,
				sectobytes(reloc->sector)+reloc->sectoff+reloc->size-1);
		fprintf(stderr, "\n");
		if (detail > 1) {
			fprintf(stderr, "  image: ");
			hexdump(ip+boff, off-boff);
			fprintf(stderr, "\n  disk : ");
			hexdump(dp+boff, off-boff);
			fprintf(stderr, "\n");
		}
	}
}

static int
datacmp(uint32_t off, uint32_t size, unsigned char *idata)
{
	readbuf_t *rbuf;

	rbuf = alloc_readbuf(off, size, 1);
	readblock(rbuf);
	if (memcmp(idata, rbuf->data, sectobytes(size)) == 0) {
		putblock(rbuf);
		return 0;
	}
	if (detail)
		fullcmp(idata, rbuf->data, sectobytes(size), off);
	else
		fprintf(stderr, " [%u-%u]: bad data\n", off, off + size - 1);
	putblock(rbuf);
	return 1;
}

#include <zlib.h>
#define CHECK_ERR(err, msg) \
if (err != Z_OK) { \
	fprintf(stderr, "%s error: %d\n", msg, err); \
	exit(1); \
}

static int
hashimage(char *name, struct hashinfo **hinfop)
{
	char *bp;
	int ifd, cc, chunkno, count;
	int isstdin = !strcmp(name, "-");
	int errors = 0;

	/* XXX */
	if (regfile)
		return hashfile(name, hinfop);

	if (isstdin)
		ifd = fileno(stdin);
	else {
		ifd = open(name, O_RDONLY, 0666);
		if (ifd < 0) {
			perror(name);
			return -1;
		}
	}

	for (chunkno = 0; ; chunkno++) {
		bp = chunkbuf;

		/*
		 * Parse the file one chunk at a time.  We read the entire
		 * chunk and hand it off.  Since we might be reading from
		 * stdin, we have to make sure we get the entire amount.
		 */
		count = sizeof(chunkbuf);
		while (count) {
			if ((cc = read(ifd, bp, count)) <= 0) {
				if (cc == 0)
					goto done;
				perror(name);
				if (!isstdin)
					close(ifd);
				return -1;
			}
			count -= cc;
			bp += cc;
		}
		errors += hashchunk(chunkno, chunkbuf, hinfop);
		nchunks++;
	}
 done:
	if (!isstdin)
		close(ifd);
	nchunks++;
	return errors;
}

/*
 * Decompress the chunk, calculating hashes
 */
static int
hashchunk(int chunkno, char *chunkbufp, struct hashinfo **hinfop)
{
	blockhdr_t *blockhdr;
	struct region *regp;
	z_stream z;
	int err, nreg;
	unsigned char hash[HASH_MAXSIZE];
	unsigned char *(*hashfunc)(const unsigned char *, unsigned long,
				   unsigned char *);
	readbuf_t *rbuf;
	int errors = 0;
#ifdef TIMEIT
	u_int64_t sstamp, estamp;
#endif

	z.zalloc = Z_NULL;
	z.zfree    = Z_NULL;
	z.opaque   = Z_NULL;
	z.next_in  = Z_NULL;
	z.avail_in = 0;
	z.next_out = Z_NULL;

	err = inflateInit(&z);
	CHECK_ERR(err, "inflateInit");
	
	memset(hash, 0, sizeof hash);

	/*
	 * Grab the header. It is uncompressed, and holds the real
	 * image size and the magic number. Advance the pointer too.
	 */
	blockhdr = (blockhdr_t *)chunkbufp;
	chunkbufp += DEFAULTREGIONSIZE;
	nregions += (uint32_t)blockhdr->regioncount;
	z.next_in = (Bytef *)chunkbufp;
	z.avail_in = blockhdr->size;
	
	setrelocs(0, 0);
	switch (blockhdr->magic) {
	case COMPRESSED_V1:
		regp = (struct region *)((struct blockhdr_V1 *)blockhdr + 1);
		break;

	case COMPRESSED_V2:
	case COMPRESSED_V3:
		regp = (struct region *)((struct blockhdr_V2 *)blockhdr + 1);
		if (blockhdr->reloccount)
			setrelocs((struct blockreloc *)
				  (regp + blockhdr->regioncount),
				  blockhdr->reloccount);
		break;

	default:
		fprintf(stderr, "Bad Magic Number!\n");
		exit(1);
	}

	/*
	 * Deterimine the hash function
	 */
	switch (hashtype) {
	case HASH_TYPE_MD5:
	default:
		hashfunc = MD5;
		hashlen = 16;
		break;
	case HASH_TYPE_SHA1:
		hashfunc = SHA1;
		hashlen = 20;
		break;
	case HASH_TYPE_RAW:
		hashfunc = 0;
		hashlen = 0;
		break;
	}

	/*
	 * Loop through all regions, decompressing and hashing data
	 * in hashblksize or smaller blocks.
	 */
	rbuf = alloc_readbuf(0, bytestosec(hashblksize), 0);
	if (rbuf == NULL) {
		fprintf(stderr, "no memory\n");
		exit(1);
	}
	for (nreg = 0; nreg < blockhdr->regioncount; nreg++) {
		uint32_t rstart, rsize, hsize;

		rstart = regp->start;
		rsize = regp->size;
		ndatabytes += sectobytes(rsize);
		while (rsize > 0) {
			if (rsize > bytestosec(hashblksize))
				hsize = bytestosec(hashblksize);
			else
				hsize = rsize;

			z.next_out = (Bytef *)rbuf->data;
			z.avail_out = sectobytes(hsize);
#ifdef TIMEIT
			sstamp = rdtsc();
#endif
			err = inflate(&z, Z_SYNC_FLUSH);
#ifdef TIMEIT
			estamp = rdtsc();
			dcycles += (estamp - sstamp);
#endif
			if (err != Z_OK && err != Z_STREAM_END) {
				fprintf(stderr, "inflate failed, err=%d\n",
					err);
				exit(1);
			}

			/*
			 * Make sure we are still in synch
			 */
			if (z.avail_out != 0) {
				fprintf(stderr,
					"inflate failed to fill buf, %d left\n",
					z.avail_out);
				exit(1);
			}
			if (err == Z_STREAM_END && hsize != rsize) {
				fprintf(stderr,
					"inflate ran out of input, %d left\n",
					rsize - hsize);
				exit(1);
			}

			if (doall ||
			    !hasrelocs(sectobytes(rstart), sectobytes(hsize))) {
				/*
				 * NULL hashfunc indicates we are doing raw
				 * comparison.  Otherwise, we compute the hash.
				 */
				if (hashfunc == 0) {
					errors += datacmp(rstart, hsize,
							  rbuf->data);
				} else {
					(void)(*hashfunc)(rbuf->data,
							  sectobytes(hsize),
							  hash);
					addhash(hinfop, chunkno, rstart, hsize,
						hash);
				}
			}
			rstart += hsize;
			rsize -= hsize;
		}
		regp++;
	}
	free_readbuf(rbuf);
	if (z.avail_in != 0) {
		fprintf(stderr,
			"too much input for chunk, %d left\n", z.avail_in);
		exit(1);
	}
	err = inflateEnd(&z);
	CHECK_ERR(err, "inflateEnd");

	return errors;
}

/*
 * Hash a regular file.
 * Here we have a problem that a random file won't necessarily be a multiple
 * of the disk sector size, and the current hashinfo layout is oriented around
 * sectors.  So the hack is this for regular files:
 *
 *  * chunkno is always 0 except for an optional partial sector at the end
 *
 *  * for a final partial sector, the size field will be 0 and chunkno will
 *    contain the number of bytes covered by the hash.
 */
static int
hashfile(char *name, struct hashinfo **hinfop)
{
	char *bp;
	int ifd, cc, chunkno, count, chunksize;
	int isstdin = !strcmp(name, "-");
	int errors = 0;

	if (isstdin)
		ifd = fileno(stdin);
	else {
		ifd = open(name, O_RDONLY, 0666);
		if (ifd < 0) {
			perror(name);
			return -1;
		}
	}

	/*
	 * For a regular file, there is nothing special about a
	 * "chunk", it is just some multiple of the hash unit size
	 * (and smaller than our chunk buffer) that we use to keep
	 * reads large.
	 */
	chunksize = (sizeof(chunkbuf) / hashblksize) * hashblksize;
	chunkno = 0;
	while (1) {
		bp = chunkbuf;

		/*
		 * Parse the file one chunk at a time.  We read the entire
		 * chunk and hand it off.  Since we might be reading from
		 * stdin, we have to make sure we get the entire amount.
		 *
		 */
		count = chunksize;
		while (count) {
			if ((cc = read(ifd, bp, count)) <= 0) {
				if (cc == 0) {
					if (count != chunksize)
						break;
					goto done;
				}
				perror(name);
				if (!isstdin)
					close(ifd);
				return -1;
			}
			count -= cc;
			bp += cc;
		}
		errors += hashfilechunk(chunkno, chunkbuf, chunksize-count,
					hinfop);
	}
 done:
	if (!isstdin)
		close(ifd);
	nchunks = chunkno + 1;
	return errors;
}

/*
 * Calculate hashs for a file chunk.
 */
static int
hashfilechunk(int chunkno, char *chunkbufp, int chunksize,
	      struct hashinfo **hinfop)
{
	int resid;
	uint32_t cursect = 0, nbytes;
	unsigned char hash[HASH_MAXSIZE];
	unsigned char *(*hashfunc)(const unsigned char *, unsigned long,
				   unsigned char *);
	unsigned char *bufp = (unsigned char *)chunkbufp;
	int errors = 0;

	memset(hash, 0, sizeof hash);

	/*
	 * Deterimine the hash function
	 */
	switch (hashtype) {
	case HASH_TYPE_MD5:
	default:
		hashfunc = MD5;
		break;
	case HASH_TYPE_SHA1:
		hashfunc = SHA1;
		break;
	case HASH_TYPE_RAW:
		hashfunc = 0;
		break;
	}

	/*
	 * Loop through the file chunk, hashing data
	 * in hashblksize or smaller blocks.
	 */
	resid = chunksize - sectobytes(bytestosec(chunksize));
	while (chunksize > 0) {
		uint32_t rstart, rsize;

		if (chunksize > hashblksize)
			nbytes = hashblksize;
		else if (chunksize >= sectobytes(1))
			nbytes = sectobytes(bytestosec(chunksize));
		else {
			assert(resid > 0);
			nbytes = chunksize;
		}

		rstart = cursect;
		rsize = bytestosec(nbytes);

		/*
		 * NULL hashfunc indicates we are doing raw
		 * comparison.  Otherwise, we compute the hash.
		 */
		if (hashfunc == 0) {
			errors += datacmp(rstart, rsize, bufp);
		} else {
			(void)(*hashfunc)(bufp, nbytes, hash);
			addhash(hinfop, nbytes >= sectobytes(1) ? 0 : resid,
				rstart, rsize, hash);
		}
		bufp += nbytes;
		cursect += bytestosec(nbytes);
		chunksize -= nbytes;
	}
	return errors;
}

static int devfd = -1;
static char *devfile;
static volatile unsigned long curreadbufmem, curreadbufs;
static volatile int readbufwanted;

#ifdef NOTHREADS
/* XXX keep the code simple */
#undef CONDVARS_WORK
#define pthread_mutex_lock(l)
#define pthread_mutex_unlock(l)
#define pthread_testcancel()
#else
static pthread_t	reader_pid;
static queue_head_t	readqueue;
static pthread_mutex_t	readbuf_mutex, readqueue_mutex;
#ifdef CONDVARS_WORK
static pthread_cond_t	readbuf_cond, readqueue_cond;
#else
int fsleep(unsigned int usecs);
#endif
static void *diskreader(void *);
#endif

/* stats */
unsigned long		maxbufsalloced, maxmemalloced;
unsigned long		readeridles, hasheridles;

void
dump_readbufs(void)
{
#ifndef NOTHREADS
	if (!nothreads)
		printf("idles: reader %lu, hasher %lu\n",
		       readeridles, hasheridles);
#endif
	fprintf(stderr, "%lu max bufs, %lu max memory\n",
		maxbufsalloced, maxmemalloced);
}

static readbuf_t *
alloc_readbuf(uint32_t start, uint32_t size, int dowait)
{
	readbuf_t *rbuf;
	size_t bufsize;

	pthread_mutex_lock(&readbuf_mutex);
	bufsize = sectobytes(size);
	if (size > hashblksize) {
		fprintf(stderr, "%s: hash region too big (%d bytes)\n",
			devfile, size);
		exit(1);
	}

	do {
		if (maxreadbufmem && curreadbufmem + bufsize > maxreadbufmem)
			rbuf = NULL;
		else
			rbuf = malloc(sizeof(*rbuf) + bufsize);

		if (rbuf == NULL) {
			if (!dowait) {
				pthread_mutex_unlock(&readbuf_mutex);
				return NULL;
			}

			readeridles++;
			readbufwanted = 1;
			/*
			 * Once again it appears that linuxthreads
			 * condition variables don't work well.
			 * We seem to sleep longer than necessary.
			 */
			do {
#ifdef CONDVARS_WORK
				pthread_cond_wait(&readbuf_cond,
						  &readbuf_mutex);
#else
				pthread_mutex_unlock(&readbuf_mutex);
				fsleep(1000);
				pthread_mutex_lock(&readbuf_mutex);
#endif
				pthread_testcancel();
			} while (readbufwanted);
		}
	} while (rbuf == NULL);

	curreadbufs++;
	curreadbufmem += bufsize;
	if (curreadbufs > maxbufsalloced)
		maxbufsalloced = curreadbufs;
	if (curreadbufmem > maxmemalloced)
		maxmemalloced = curreadbufmem;
	pthread_mutex_unlock(&readbuf_mutex);

	queue_init(&rbuf->chain);
	rbuf->region.start = start;
	rbuf->region.size = size;

	return rbuf;
}

static void
free_readbuf(readbuf_t *rbuf)
{
	assert(rbuf != NULL);

	pthread_mutex_lock(&readbuf_mutex);
	curreadbufs--;
	curreadbufmem -= sectobytes(rbuf->region.size);
	assert(curreadbufmem >= 0);
	if (readbufwanted) {
		readbufwanted = 0;
#ifdef CONDVARS_WORK
		pthread_cond_signal(&readbuf_cond);
#endif
	}
	free(rbuf);
	pthread_mutex_unlock(&readbuf_mutex);
}

static int
startreader(char *name, struct hashinfo *hinfo)
{
	devfd = open(name, O_RDONLY, 0666);
	if (devfd < 0) {
		perror(name);
		return -1;
	}
	devfile = name;

#ifndef NOTHREADS
	if (!nothreads) {
		queue_init(&readqueue);
		pthread_mutex_init(&readqueue_mutex, 0);
#ifdef CONDVARS_WORK
		pthread_cond_init(&readqueue_cond, 0);
#endif
		if (pthread_create(&reader_pid, NULL, diskreader, hinfo)) {
			fprintf(stderr, "Failed to start disk reader thread\n");
			return -1;
		}
	}
#endif

	return 0;
}

static void
stopreader(void)
{
#ifndef NOTHREADS
	if (!nothreads) {
		void *status;

		pthread_cancel(reader_pid);
		pthread_join(reader_pid, &status);
	}
#endif
	close(devfd);
	devfd = -1;
	devfile = 0;
}

static readbuf_t *
getblock(struct hashregion *reg)
{
#ifndef NOTHREADS
	readbuf_t	*rbuf = 0;
	static int	gotone;

	if (!nothreads) {
		pthread_mutex_lock(&readqueue_mutex);
		if (queue_empty(&readqueue)) {
			if (gotone)
				hasheridles++;
			do {
#ifdef CONDVARS_WORK
				pthread_cond_wait(&readqueue_cond,
						  &readqueue_mutex);
#else
				pthread_mutex_unlock(&readqueue_mutex);
				fsleep(1000);
				pthread_mutex_lock(&readqueue_mutex);
#endif
				pthread_testcancel();
			} while (queue_empty(&readqueue));
		}
		queue_remove_first(&readqueue, rbuf, readbuf_t *, chain);
		gotone = 1;
		pthread_mutex_unlock(&readqueue_mutex);

		if (rbuf->region.start != reg->region.start &&
		    rbuf->region.size != reg->region.size) {
			fprintf(stderr, "reader/hasher out of sync!\n");
			exit(2);
		}

		return rbuf;
	}
#endif
	rbuf = alloc_readbuf(reg->region.start, reg->region.size, 1);
	readblock(rbuf);
	return rbuf;
}

static void
putblock(struct readbuf *rbuf)
{
	free_readbuf(rbuf);
}

static void
readblock(readbuf_t *rbuf)
{
	size_t size;
	ssize_t cc;
#ifdef TIMEIT
	u_int64_t sstamp, estamp;
#endif

	size = sectobytes(rbuf->region.size);
#ifdef TIMEIT
	sstamp = rdtsc();
#endif
	if (lseek(devfd, sectobytes(rbuf->region.start), SEEK_SET) < 0) {
		perror(devfile);
		exit(3);
	}
	cc = read(devfd, rbuf->data, size);
	if (cc != size) {
		if (cc < 0)
			perror(devfile);
		else
			fprintf(stderr,
				"%s: incomplete read (%d) at sect %u\n",
				devfile, cc, rbuf->region.start);
		exit(3);
	}
#ifdef TIMEIT
	estamp = rdtsc();
	rcycles += (estamp - sstamp);
#endif
}

#ifndef NOTHREADS
void *
diskreader(void *arg)
{
	struct hashinfo *hinfo = arg;
	struct hashregion *reg;
	struct readbuf *rbuf;
	uint32_t i;

	if (detail)
		fprintf(stderr, "Reader thread running\n");

	for (i = 0, reg = hinfo->regions; i < hinfo->nregions; i++, reg++) {
		/* XXX maxreadbufmem has to at least hold one hash region */
		if (maxreadbufmem < sectobytes(reg->region.size))
			maxreadbufmem = sectobytes(reg->region.size);
		rbuf = alloc_readbuf(reg->region.start, reg->region.size, 1);
		readblock(rbuf);
		pthread_mutex_lock(&readqueue_mutex);
		queue_enter(&readqueue, rbuf, readbuf_t *, chain);
#ifdef CONDVARS_WORK
		pthread_cond_signal(&readqueue_cond);
#endif
		pthread_mutex_unlock(&readqueue_mutex);
	}
	return 0;
}

#ifndef CONDVARS_WORK
/*
 * Sleep. Basically wraps nanosleep, but since the threads package uses
 * signals, it keeps ending early!
 */
int
fsleep(unsigned int usecs)
{
	struct timespec time_to_sleep, time_not_slept;
	int	foo;

	time_to_sleep.tv_nsec  = (usecs % 1000000) * 1000;
	time_to_sleep.tv_sec   = usecs / 1000000;
	time_not_slept.tv_nsec = 0;
	time_not_slept.tv_sec  = 0;

	while ((foo = nanosleep(&time_to_sleep, &time_not_slept)) != 0) {
		if (foo < 0 && errno != EINTR) {
			return -1;
		}
		time_to_sleep.tv_nsec  = time_not_slept.tv_nsec;
		time_to_sleep.tv_sec   = time_not_slept.tv_sec;
		time_not_slept.tv_nsec = 0;
		time_not_slept.tv_sec  = 0;
	}
	return 0;
}
#endif
#endif

static void
dump_stats(int sig)
{
#ifndef NOTHREADS
	if (sig && !nothreads && pthread_self() == reader_pid)
		return;
#endif

	printf("%s: %lu chunks, ", imagename, nchunks);
	if (create)
		printf("%lu regions, ", nregions);
	else
		printf("%u of %u hashes bad, ", badhashes, checkedhashes);
	printf("%lu hashregions, %llu data bytes\n", nhregions, ndatabytes);
}
