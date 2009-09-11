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
#include <errno.h>
#include <openssl/sha.h>
#include <openssl/md5.h>
#ifndef NOTHREADS
#include <pthread.h>
#endif

#include "imagehdr.h"
#include "queue.h"

#ifndef linux
#define TIMEIT
#endif

#define HASH_MAGIC	".ndzsig"
#define HASH_VERSION	0x20031107
#define HASHBLK_SIZE	(64*1024)
#define HASH_MAXSIZE	20

struct hashregion {
	struct region region;
	uint32_t chunkno;
	unsigned char hash[HASH_MAXSIZE];
};

struct hashinfo {
	uint8_t	 magic[8];
	uint32_t version;
	uint32_t hashtype;
	uint32_t nregions;
	uint8_t	 pad[12];
	struct hashregion regions[0];
};

#define HASH_TYPE_MD5	1
#define HASH_TYPE_SHA1	2


#define MAXREADBUFMEM	(8*HASHBLK_SIZE)	/* 0 == unlimited */

typedef struct readbuf {
	queue_chain_t chain;
	struct region region;
	char data[0];
} readbuf_t;
static unsigned long maxreadbufmem = MAXREADBUFMEM;

static int detail = 0;
static int create = 0;
static int nothreads = 0;
static int hashtype = HASH_TYPE_MD5;
static unsigned long long ndatabytes;
static unsigned long nchunks, nregions, nhregions;

static char chunkbuf[SUBBLOCKSIZE];

static void usage(void);
static int gethashinfo(char *name, struct hashinfo **hinfo);
static int readhashinfo(char *name, struct hashinfo **hinfop);
static int checkhash(char *name, struct hashinfo *hinfo);
static void dumphash(char *name, struct hashinfo *hinfo);
static int createhash(char *name, struct hashinfo **hinfop);
static int hashimage(char *name, struct hashinfo **hinfop);
static void hashchunk(int chunkno, char *chunkbufp, struct hashinfo **hinfop);
static char *spewhash(char *h);

static int startreader(char *name, struct hashinfo *hinfo);
static void stopreader(void);
static struct readbuf *getblock(struct hashregion *reg);
static void putblock(readbuf_t *rbuf);
static void readblock(readbuf_t *rbuf);
static readbuf_t *alloc_readbuf(uint32_t start, uint32_t size, int dowait);
static void free_readbuf(readbuf_t *rbuf);
static void dump_readbufs(void);

#define sectobytes(s)	((off_t)(s) * SECSIZE)
#define bytestosec(b)	(uint32_t)((b) / SECSIZE)

int
main(int argc, char **argv)
{
	int ch, version = 0;
	extern char build_info[];
	struct hashinfo *hashinfo = 0;

	while ((ch = getopt(argc, argv, "cdvhnD:")) != -1)
		switch(ch) {
		case 'c':
			create++;
			break;
		case 'D':
			if (strcmp(optarg, "md5") == 0)
				hashtype = HASH_TYPE_MD5;
			else if (strcmp(optarg, "sha1") == 0)
				hashtype = HASH_TYPE_SHA1;
			else {
				fprintf(stderr, "Invalid digest type `%s'\n",
					optarg);
				usage();
			}
			break;
		case 'd':
			detail++;
			break;
		case 'n':
			nothreads++;
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

	if ((create && argc < 1) || (!create && argc < 2))
		usage();

	/*
	 * Ensure we can open both files before we do the expensive stuff.
	 */
	if (strcmp(argv[0], "-") != 0 && access(argv[0], R_OK) != 0) {
		perror("image file");
		exit(1);
	}
	if (!create && access(argv[1], R_OK) != 0) {
		perror("device file");
		exit(1);
	}

	/*
	 * Create a hash file
	 */
	if (create) {
		if (createhash(argv[0], &hashinfo))
			exit(2);
		dumphash(argv[0], hashinfo);
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
		"imagehash -c [-d] <image-filename>\n"
		"    create a signature file for the specified image\n"
		"imagehash -v\n"
		"    print version info and exit\n");
	exit(1);
}	

/*
 * Create the signature file name
 */
static char *
signame(char *name)
{
	char *hfile;

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
	if (strcmp(hi.magic, HASH_MAGIC) != 0 || hi.version != HASH_VERSION) {
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
	return 0;
}

static void
addhash(struct hashinfo **hinfop, int chunkno, uint32_t start, uint32_t size,
	char hash[HASH_MAXSIZE])
{
	struct hashinfo *hinfo = *hinfop;
	int nreg;

	if (hinfo == 0) {
		nreg = 0;
		hinfo = calloc(1, sizeof(*hinfo) + sizeof(struct hashregion));
	} else {
		nreg = hinfo->nregions;
		hinfo = realloc(hinfo, sizeof(*hinfo) +
				(nreg+1) * sizeof(struct hashregion));
	}
	if (hinfo == 0) {
		fprintf(stderr, "out of memory for hash map\n");
		exit(1);
	}
	*hinfop = hinfo;

	hinfo->regions[nreg].chunkno = chunkno;
	hinfo->regions[nreg].region.start = start;
	hinfo->regions[nreg].region.size = size;
	memcpy(hinfo->regions[nreg].hash, hash, HASH_MAXSIZE);
	hinfo->nregions++;
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
			       reg->region.start + reg->region.size - 1,
			       reg->chunkno, spewhash(reg->hash));
		}
	}
}

static char *
spewhash(char *h)
{
	static char hbuf[33];
	uint32_t *foo = (uint32_t *)h;

	snprintf(hbuf, sizeof hbuf, "%08x%08x%08x%08x",
		 foo[0], foo[1], foo[2], foo[3]);
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

	hfile = signame(name);
	ofd = open(hfile, O_RDWR|O_CREAT, 0666);
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
	strcpy(hinfo->magic, HASH_MAGIC);
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

	free(hfile);
	nhregions = hinfo->nregions;
	printf("%s: %lu chunks, %lu regions, %lu hashregions, %qu data bytes\n",
	       name, nchunks, nregions, nhregions, ndatabytes);
#ifdef TIMEIT
	printf("%qu bytes: inflate cycles: %qu\n", ndatabytes, dcycles);
#endif
	return 0;
}

static int
checkhash(char *name, struct hashinfo *hinfo)
{
	uint32_t i, inbad, badstart, badsize, reportbad;
	uint32_t badhashes, badchunks, lastbadchunk;
	uint64_t badhashdata;
	struct hashregion *reg;
	int hashlen, chunkno;
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
		hashstr = "MD5";
		break;
	case HASH_TYPE_SHA1:
		hashlen = 20;
		hashfunc = SHA1;
		hashstr = "SHA1";
		break;
	}
	fprintf(stderr, "Checking disk contents using %s digest\n", hashstr);

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
			printf("  sig  %s\n", spewhash(reg->hash));
			printf("  disk %s\n", spewhash(hash));
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
				fprintf(stderr, "%s: bad hash [%u-%u]\n",
					name, badstart, badstart + badsize - 1);
			reportbad = inbad = 0;
		}
	}
	/*
	 * Finished on a sour note, report the final bad stretch.
	 */
	if (inbad && detail)
		fprintf(stderr, "%s: bad hash [%u-%u]\n",
			name, badstart, badstart + badsize - 1);

	stopreader();

	nhregions = hinfo->nregions;
	printf("%s: %lu chunks, %lu hashregions, %qu data bytes\n",
	       name, nchunks, nhregions, ndatabytes);
	if (badhashes)
		printf("%s: %u regions (%d chunks) had bad hashes, "
		       "%qu bytes affected\n",
		       name, badhashes, badchunks, badhashdata);
	dump_readbufs();
#ifdef TIMEIT
	printf("%qu bytes: read cycles: %qu, hash cycles: %qu, cmp cycles: %qu\n",
	       ndatabytes, rcycles, hcycles, ccycles);
#endif
	return 0;
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
		hashchunk(chunkno, chunkbuf, hinfop);
	}
 done:
	if (!isstdin)
		close(ifd);
	nchunks = chunkno + 1;
	return 0;
}

/*
 * Decompress the chunk, calculating hashes
 */
static void
hashchunk(int chunkno, char *chunkbufp, struct hashinfo **hinfop)
{
	blockhdr_t *blockhdr;
	struct region *regp;
	z_stream z;
	int err, nreg;
	char hash[HASH_MAXSIZE];
	unsigned char *(*hashfunc)(const unsigned char *, unsigned long,
				   unsigned char *);
	readbuf_t *rbuf;
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
	nregions += blockhdr->regioncount;
	z.next_in = chunkbufp;
	z.avail_in = blockhdr->size;
	
	switch (blockhdr->magic) {
	case COMPRESSED_V1:
		regp = (struct region *)((struct blockhdr_V1 *)blockhdr + 1);
		break;

	case COMPRESSED_V2:
		regp = (struct region *)((struct blockhdr_V2 *)blockhdr + 1);
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
		break;
	case HASH_TYPE_SHA1:
		hashfunc = SHA1;
		break;
	}

	/*
	 * Loop through all regions, decompressing and hashing data
	 * in HASHBLK_SIZE or smaller blocks.
	 */
	rbuf = alloc_readbuf(0, bytestosec(HASHBLK_SIZE), 0);
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
			if (rsize > bytestosec(HASHBLK_SIZE))
				hsize = bytestosec(HASHBLK_SIZE);
			else
				hsize = rsize;

			z.next_out = rbuf->data;
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

			/*
			 * Compute the hash
			 */
			(void)(*hashfunc)(rbuf->data, sectobytes(hsize), hash);
			addhash(hinfop, chunkno, rstart, hsize, hash);

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
	if (size > HASHBLK_SIZE) {
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

	for (i = 0, reg = hinfo->regions; i < hinfo->nregions; i++, reg++) {
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
