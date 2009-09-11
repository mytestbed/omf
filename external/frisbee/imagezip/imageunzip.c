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
 * Usage: imageunzip <input file>
 *
 * Writes the uncompressed data to stdout.
 */

#include <stdio.h>
#include <stdlib.h>
#include <fcntl.h>
#include <assert.h>
#include <unistd.h>
#include <string.h>
#include <zlib.h>
#include <sys/types.h>
#include <sys/time.h>
#ifndef linux
#include <sys/disklabel.h>
#endif
#include "imagehdr.h"
#include "queue.h"
#ifndef NOTHREADS
#include <pthread.h>
#endif

/*
 * Define this if you want to test frisbee's random presentation of chunks
 */
#ifndef FRISBEE
#define FAKEFRISBEE
#endif

#define MAXWRITEBUFMEM	0	/* 0 == unlimited */

long long totaledata = 0;
long long totalrdata = 0;

/*
 * In slice mode, we read the DOS MBR to find out where the slice is on
 * the raw disk, and then seek to that spot. This avoids sillyness in
 * the BSD kernel having to do with disklabels. 
 *
 * These numbers are in sectors.
 */
static long		outputminsec	= 0;
static long		outputmaxsec	= 0;

/* Why is this not defined in a public header file? */
#define BOOT_MAGIC	0xAA55

#define CHECK_ERR(err, msg) { \
    if (err != Z_OK) { \
        fprintf(stderr, "%s error: %d\n", msg, err); \
        exit(1); \
    } \
}

#define sectobytes(s)	((off_t)(s) * SECSIZE)
#define bytestosec(b)	(uint32_t)((b) / SECSIZE)

#define OUTSIZE (256 * 1024)
char		zeros[OUTSIZE];

static int	 dostype = -1;
static int	 slice = 0;
static int	 debug = 0;
static int	 outfd;
static int	 dofill = 0;
static int	 nothreads = 0;
static int	 rdycount;
static int	 imageversion = 1;
#ifndef FRISBEE
static int	 infd;
static int	 version= 0;
static unsigned	 fillpat= 0;
static int	 dots   = 0;
static int	 dotcol;
static char	 chunkbuf[SUBBLOCKSIZE];
static struct timeval stamp;
#endif
int		 readmbr(int slice);
int		 fixmbr(int slice, int dtype);
static int	 inflate_subblock(char *);
void		 writezeros(off_t offset, off_t zcount);
void		 writedata(off_t offset, size_t count, void *buf);

static void	getrelocinfo(blockhdr_t *hdr);
static void	applyrelocs(off_t offset, size_t cc, void *buf);

static int	 seekable;
static off_t	 nextwriteoffset;

static int	 imagetoobigwarned;

#ifndef FRISBEE
static int	 docrconly = 0;
static u_int32_t crc;
extern void	 compute_crc(u_char *buf, int blen, u_int32_t *crcp);
#endif

#ifdef FAKEFRISBEE
#include <sys/stat.h>

static int	dofrisbee;
static int	*chunklist, *nextchunk;
#endif

/*
 * Some stats
 */
unsigned long decompblocks;
unsigned long writeridles;

#ifdef NOTHREADS
#define		threadinit()
#define		threadwait()
#define		threadquit()

/* XXX keep the code simple */
#define pthread_mutex_lock(l)
#define pthread_mutex_unlock(l)
#define pthread_testcancel()
#undef CONDVARS_WORK
#else
static void	 threadinit(void);
static void	 threadwait(void);
static void	 threadquit(void);
static void	*DiskWriter(void *arg);

static int	writeinprogress; /* XXX */
static pthread_t child_pid;
static pthread_mutex_t	writequeue_mutex;	
#ifdef CONDVARS_WORK
static pthread_cond_t	writequeue_cond;	
#endif
#endif

/*
 * A queue of ready to write data blocks.
 */
typedef struct {
	int		refs;
	size_t		size;
	char		data[0];
} buffer_t;

typedef struct {
	queue_chain_t	chain;
	off_t		offset;
	off_t		size;
	buffer_t	*buf;
	char		*data;
} writebuf_t;

static unsigned long	maxwritebufmem = MAXWRITEBUFMEM;
static volatile unsigned long	curwritebufmem, curwritebufs;
#ifndef NOTHREADS
static queue_head_t	writequeue;
static pthread_mutex_t	writebuf_mutex;
#ifdef CONDVARS_WORK
static pthread_cond_t	writebuf_cond;
#endif
#endif
static volatile int	writebufwanted;

/* stats */
unsigned long		maxbufsalloced, maxmemalloced;
unsigned long		splits;

#ifndef CONDVARS_WORK
int fsleep(unsigned int usecs);
#endif

void
dump_writebufs(void)
{
	fprintf(stderr, "%lu max bufs, %lu max memory\n",
		maxbufsalloced, maxmemalloced);
	fprintf(stderr, "%lu buffers split\n",
		splits);
}

static writebuf_t *
alloc_writebuf(off_t offset, off_t size, int allocbuf, int dowait)
{
	writebuf_t *wbuf;
	buffer_t *buf = NULL;
	size_t bufsize;

	pthread_mutex_lock(&writebuf_mutex);
	wbuf = malloc(sizeof(*wbuf));
	if (wbuf == NULL) {
		fprintf(stderr, "could not alloc writebuf header\n");
		exit(1);
	}
	bufsize = allocbuf ? size : 0;
	if (bufsize) {
		do {
			if (maxwritebufmem &&
			    curwritebufmem + bufsize > maxwritebufmem)
				buf = NULL;
			else
				buf = malloc(sizeof(buffer_t) + bufsize);

			if (buf == NULL) {
				if (!dowait) {
					free(wbuf);
					pthread_mutex_unlock(&writebuf_mutex);
					return NULL;
				}

				decompblocks++;
				writebufwanted = 1;
				/*
				 * Once again it appears that linuxthreads
				 * condition variables don't work well.
				 * We seem to sleep longer than necessary.
				 */
				do {
#ifdef CONDVARS_WORK
					pthread_cond_wait(&writebuf_cond,
							  &writebuf_mutex);
#else
					pthread_mutex_unlock(&writebuf_mutex);
					fsleep(1000);
					pthread_mutex_lock(&writebuf_mutex);
#endif
					pthread_testcancel();
				} while (writebufwanted);
			}
		} while (buf == NULL);
		buf->refs = 1;
		buf->size = bufsize;
	}
	curwritebufs++;
	curwritebufmem += bufsize;
	if (curwritebufs > maxbufsalloced)
		maxbufsalloced = curwritebufs;
	if (curwritebufmem > maxmemalloced)
		maxmemalloced = curwritebufmem;
	pthread_mutex_unlock(&writebuf_mutex);

	queue_init(&wbuf->chain);
	wbuf->offset = offset;
	wbuf->size = size;
	wbuf->buf = buf;
	wbuf->data = buf ? buf->data : NULL;

	return wbuf;
}

static writebuf_t *
split_writebuf(writebuf_t *wbuf, off_t doff, int dowait)
{
	writebuf_t *nwbuf;
	off_t size;

	assert(wbuf->buf != NULL);

	splits++;
	assert(doff < wbuf->size);
	size = wbuf->size - doff;
	nwbuf = alloc_writebuf(wbuf->offset+doff, size, 0, dowait);
	if (nwbuf) {
		wbuf->size -= size;
		pthread_mutex_lock(&writebuf_mutex);
		wbuf->buf->refs++;
		pthread_mutex_unlock(&writebuf_mutex);
		nwbuf->buf = wbuf->buf;
		nwbuf->data = wbuf->data + doff;
	}
	return nwbuf;
}

static void
free_writebuf(writebuf_t *wbuf)
{
	assert(wbuf != NULL);

	pthread_mutex_lock(&writebuf_mutex);
	if (wbuf->buf && --wbuf->buf->refs == 0) {
		curwritebufs--;
		curwritebufmem -= wbuf->buf->size;
		assert(curwritebufmem >= 0);
		free(wbuf->buf);
		if (writebufwanted) {
			writebufwanted = 0;
#ifdef CONDVARS_WORK
			pthread_cond_signal(&writebuf_cond);
#endif
		}
	}
	free(wbuf);
	pthread_mutex_unlock(&writebuf_mutex);
}

static void
dowrite_request(writebuf_t *wbuf)
{
	off_t offset, size;
	void *buf;
	
	offset = wbuf->offset;
	size = wbuf->size;
	buf = wbuf->data;
	assert(offset >= 0);
	assert(size > 0);

	/*
	 * Adjust for partition start and ensure data fits
	 * within partition boundaries.
	 */
	offset += sectobytes(outputminsec);
	assert((offset & (SECSIZE-1)) == 0);
	if (outputmaxsec > 0 && offset + size > sectobytes(outputmaxsec)) {
		if (!imagetoobigwarned) {
			fprintf(stderr, "WARNING: image too large "
				"for target slice, truncating\n");
			imagetoobigwarned = 1;
		}
		if (offset >= sectobytes(outputmaxsec)) {
			free_writebuf(wbuf);
			return;
		}
		size = sectobytes(outputmaxsec) - offset;
		wbuf->size = size;
	}
	wbuf->offset = offset;

	totaledata += size;

	if (nothreads) {
		/*
		 * Null buf means its a request to zero.
		 * If we are not filling, just return.
		 */
		if (buf == NULL) {
			if (dofill)
				writezeros(offset, size);
		} else {
			assert(size <= OUTSIZE);

			/*
			 * Handle any relocations
			 */
			applyrelocs(offset, (size_t)size, buf);
			writedata(offset, (size_t)size, buf);
		}
		free_writebuf(wbuf);
		return;
	}

#ifndef NOTHREADS
	if (buf == NULL) {
		if (!dofill) {
			free_writebuf(wbuf);
			return;
		}
	} else {
		assert(size <= OUTSIZE);

		/*
		 * Handle any relocations
		 */
		applyrelocs(offset, (size_t)size, buf);
	}

	/*
	 * Queue it up for the writer thread
	 */
	pthread_mutex_lock(&writequeue_mutex);
	queue_enter(&writequeue, wbuf, writebuf_t *, chain);
#ifdef CONDVARS_WORK
	pthread_cond_signal(&writequeue_cond);
#endif
	pthread_mutex_unlock(&writequeue_mutex);
#endif
}

static inline int devread(int fd, void *buf, size_t size)
{
	assert((size & (SECSIZE-1)) == 0);
	return read(fd, buf, size);
}

#ifndef FRISBEE
static void
usage(void)
{
	fprintf(stderr, "usage: "
		"imageunzip options <input filename> [output filename]\n"
		" -v              Print version info and exit\n"
		" -s slice        Output to DOS slice (DOS numbering 1-4)\n"
		"                 NOTE: Must specify a raw disk device.\n"
		" -D DOS-ptype    Set the DOS partition type in slice mode.\n"
		" -z              Write zeros to free blocks.\n"
		" -p pattern      Write 32 bit pattern to free blocks.\n"
		"                 NOTE: Use -z/-p to avoid seeking.\n"
		" -o              Output 'dots' indicating progress\n"
		" -n              Single threaded (slow) mode\n"
		" -d              Turn on progressive levels of debugging\n"
		" -W size         MB of memory to use for write buffering\n");
	exit(1);
}	

int
main(int argc, char **argv)
{
	int		i, ch;
	extern char	build_info[];
	struct timeval  estamp;

#ifdef NOTHREADS
	nothreads = 1;
#endif
	while ((ch = getopt(argc, argv, "vdhs:zp:onFD:W:C")) != -1)
		switch(ch) {
#ifdef FAKEFRISBEE
		case 'F':
			dofrisbee++;
			break;
#endif
		case 'd':
			debug++;
			break;

		case 'n':
			nothreads++;
			break;

		case 'v':
			version++;
			break;

		case 'o':
			dots++;
			break;

		case 's':
			slice = atoi(optarg);
			break;

		case 'D':
			dostype = atoi(optarg);
			break;

		case 'p':
			fillpat = strtoul(optarg, NULL, 0);
		case 'z':
			dofill++;
			break;

		case 'C':
			docrconly++;
			dofill++;
			seekable = 0;
			break;

#ifndef NOTHREADS
		case 'W':
			maxwritebufmem = atoi(optarg);
			if (maxwritebufmem >= 4096)
				maxwritebufmem = MAXWRITEBUFMEM;
			maxwritebufmem *= (1024 * 1024);
			break;
#endif

		case 'h':
		case '?':
		default:
			usage();
		}
	argc -= optind;
	argv += optind;

	if (version || debug) {
		fprintf(stderr, "%s\n", build_info);
		if (version)
			exit(0);
	}

	if (argc < 1 || argc > 2)
		usage();

	if (fillpat) {
		unsigned	*bp = (unsigned *) &zeros;

		for (i = 0; i < sizeof(zeros)/sizeof(unsigned); i++)
			*bp++ = fillpat;
	}

	if (strcmp(argv[0], "-")) {
		if ((infd = open(argv[0], O_RDONLY, 0666)) < 0) {
			perror("opening input file");
			exit(1);
		}
	}
	else
		infd = fileno(stdin);

	if (docrconly)
		outfd = -1;
	else if (argc == 2 && strcmp(argv[1], "-")) {
		if ((outfd =
		     open(argv[1], O_RDWR|O_CREAT|O_TRUNC, 0666)) < 0) {
			perror("opening output file");
			exit(1);
		}
	}
	else
		outfd = fileno(stdout);

	/*
	 * If the output device isn't seekable we must modify our behavior:
	 * we cannot really handle slice mode, we must always zero fill
	 * (cannot skip free space) and we cannot use pwrite.
	 */
	if (lseek(outfd, (off_t)0, SEEK_SET) < 0) {
		if (slice) {
			fprintf(stderr, "Output file is not seekable, "
				"cannot specify a slice\n");
			exit(1);
		}
		if (!dofill && !docrconly)
			fprintf(stderr,
				"WARNING: output file is not seekable, "
				"must zero-fill free space\n");
		dofill = 1;
		seekable = 0;
	} else
		seekable = 1;

	if (slice) {
		off_t	minseek;
		
		if (readmbr(slice)) {
			fprintf(stderr, "Failed to read MBR\n");
			exit(1);
		}
		minseek = sectobytes(outputminsec);
		
		if (lseek(outfd, minseek, SEEK_SET) < 0) {
			perror("Setting seek pointer to slice");
			exit(1);
		}
	}

	threadinit();
	gettimeofday(&stamp, 0);
	
#ifdef FAKEFRISBEE
	if (dofrisbee) {
		struct stat st;
		int numchunks, i;

		if (fstat(infd, &st) < 0) {
			fprintf(stderr, "Cannot stat input file\n");
			exit(1);
		}
		numchunks = st.st_size / SUBBLOCKSIZE;

		chunklist = (int *) calloc(numchunks+1, sizeof(*chunklist));
		assert(chunklist != NULL);

		for (i = 0; i < numchunks; i++)
			chunklist[i] = i;
		chunklist[i] = -1;

		srandom((long)(stamp.tv_usec^stamp.tv_sec));
		for (i = 0; i < 50 * numchunks; i++) {
			int c1 = random() % numchunks;
			int c2 = random() % numchunks;
			int t1 = chunklist[c1];
			int t2 = chunklist[c2];

			chunklist[c2] = t1;
			chunklist[c1] = t2;
		}
		nextchunk = chunklist;
	}
#endif

	while (1) {
		int	count = sizeof(chunkbuf);
		char	*bp   = chunkbuf;
		
#ifdef FAKEFRISBEE
		if (dofrisbee) {
			if (*nextchunk == -1)
				goto done;
			if (lseek(infd, (off_t)*nextchunk * SUBBLOCKSIZE,
				  SEEK_SET) < 0) {
				perror("seek failed");
				exit(1);
			}
			nextchunk++;
		}
#endif
		/*
		 * Decompress one subblock at a time. We read the entire
		 * chunk and hand it off. Since we might be reading from
		 * stdin, we have to make sure we get the entire amount.
		 */
		while (count) {
			int	cc;
			
			if ((cc = read(infd, bp, count)) <= 0) {
				if (cc == 0)
					goto done;
				perror("reading zipped image");
				exit(1);
			}
			count -= cc;
			bp    += cc;
		}
		if (inflate_subblock(chunkbuf))
			break;
	}
 done:
	close(infd);

	/* This causes the output queue to drain */
	threadquit();
	
	/* Set the MBR type if necesary */
	if (slice && dostype >= 0)
		fixmbr(slice, dostype);

	gettimeofday(&estamp, 0);
	estamp.tv_sec -= stamp.tv_sec;
	if (debug != 1 && dots) {
		while (dotcol++ <= 60)
			fprintf(stderr, " ");
		
		fprintf(stderr, "%4ld %13qd\n", estamp.tv_sec, totaledata);
	}
	else {
		fprintf(stderr, "Wrote %qd bytes (%qd actual) in %ld seconds\n",
			totaledata, totalrdata, estamp.tv_sec);
		fprintf(stderr, "%lu %lu %d\n",
			decompblocks, writeridles, rdycount);
	}
	if (debug)
		fprintf(stderr, "decompressor blocked: %lu, "
			"writer idle: %lu, writes performed: %d\n",
			decompblocks, writeridles, rdycount);
	if (docrconly)
		fprintf(stderr, "%s: CRC=%u\n", argv[0], ~crc);
	dump_writebufs();
	return 0;
}
#else
/*
 * When compiled for frisbee, act as a library.
 */
int
ImageUnzipInit(char *filename, int _slice, int _debug, int _fill,
	       int _nothreads, int _dostype, unsigned long _writebufmem)
{
	if (outfd >= 0)
		close(outfd);

	if ((outfd = open(filename, O_RDWR|O_CREAT|O_TRUNC, 0666)) < 0) {
		perror("opening output file");
		exit(1);
	}
	slice     = _slice;
	debug     = _debug;
	dofill    = _fill;
	nothreads = _nothreads;
	dostype   = _dostype;
#ifndef NOTHREADS
	maxwritebufmem = _writebufmem;
#endif

	/*
	 * If the output device isn't seekable we must modify our behavior:
	 * we cannot really handle slice mode, we must always zero fill
	 * (cannot skip free space) and we cannot use pwrite.
	 */
	if (lseek(outfd, (off_t)0, SEEK_SET) < 0) {
		if (slice) {
			fprintf(stderr, "Output file is not seekable, "
				"cannot specify a slice\n");
			exit(1);
		}
		if (!dofill)
			fprintf(stderr,
				"WARNING: output file is not seekable, "
				"must zero-fill free space\n");
		dofill = 1;
		seekable = 0;
	} else
		seekable = 1;

	if (slice) {
		off_t	minseek;
		
		if (readmbr(slice)) {
			fprintf(stderr, "Failed to read MBR\n");
			exit(1);
		}
		minseek = sectobytes(outputminsec);
		
		if (lseek(outfd, minseek, SEEK_SET) < 0) {
			perror("Setting seek pointer to slice");
			exit(1);
		}
	}
	threadinit();
	return 0;
}

void
ImageUnzipSetMemory(unsigned long _writebufmem)
{
#ifndef NOTHREADS
	maxwritebufmem = _writebufmem;
#endif
}

int
ImageUnzipChunk(char *chunkdata)
{
	return inflate_subblock(chunkdata);
}

void
ImageUnzipFlush(void)
{
	threadwait();
}

int
ImageUnzipQuit(void)
{
	threadquit();

	/* Set the MBR type if necesary */
	if (slice && dostype >= 0)
		fixmbr(slice, dostype);

	fprintf(stderr, "Wrote %qd bytes (%qd actual)\n",
		totaledata, totalrdata);
	fprintf(stderr, "%lu %lu %d\n", decompblocks, writeridles, rdycount);
	return 0;
}
#endif

#ifndef NOTHREADS
static void
threadinit(void)
{
	static int	called;

	if (nothreads)
		return;

	decompblocks = writeridles = 0;
	imagetoobigwarned = 0;

	/*
	 * Allocate blocks for the ready queue.
	 */
	queue_init(&writequeue);

	if (!called) {
		called = 1;
		pthread_mutex_init(&writebuf_mutex, 0);
		pthread_mutex_init(&writequeue_mutex, 0);
#ifdef CONDVARS_WORK
		pthread_cond_init(&writebuf_cond, 0);
		pthread_cond_init(&writequeue_cond, 0);
#endif
	}

	if (pthread_create(&child_pid, NULL, DiskWriter, (void *)0)) {
		fprintf(stderr, "Failed to create pthread!\n");
		exit(1);
	}
}

static void
threadwait(void)
{
	int		done;

	if (nothreads)
		return;

	while (1) {
		pthread_mutex_lock(&writequeue_mutex);
		done = (queue_empty(&writequeue) && !writeinprogress);
		pthread_mutex_unlock(&writequeue_mutex);
		if (done)
			return;
		usleep(300000);
	}
}

static void
threadquit(void)
{
	void	       *ignored;

	if (nothreads)
		return;

	threadwait();
	pthread_cancel(child_pid);
	pthread_join(child_pid, &ignored);
}

void *
DiskWriter(void *arg)
{
	writebuf_t	*wbuf = 0;
	static int	gotone;

	while (1) {
		pthread_testcancel();

		pthread_mutex_lock(&writequeue_mutex);
		if (queue_empty(&writequeue)) {
			if (gotone)
				writeridles++;
			do {
#ifdef CONDVARS_WORK
				pthread_cond_wait(&writequeue_cond,
						  &writequeue_mutex);
#else
				pthread_mutex_unlock(&writequeue_mutex);
				fsleep(1000);
				pthread_mutex_lock(&writequeue_mutex);
#endif
				pthread_testcancel();
			} while (queue_empty(&writequeue));
		}
		queue_remove_first(&writequeue, wbuf, writebuf_t *, chain);
		writeinprogress = 1; /* XXX */
		gotone = 1;
		pthread_mutex_unlock(&writequeue_mutex);

		if (wbuf->data == NULL) {
			writezeros(wbuf->offset, wbuf->size);
		} else {
			rdycount++;
			assert(wbuf->size <= OUTSIZE);
			writedata(wbuf->offset, (size_t)wbuf->size, wbuf->data);
		}
		free_writebuf(wbuf);
		writeinprogress = 0; /* XXX, ok as unlocked access */
	}
}
#endif

static int
inflate_subblock(char *chunkbufp)
{
	int		cc, err, count, ibsize = 0, ibleft = 0;
	z_stream	d_stream; /* inflation stream */
	blockhdr_t	*blockhdr;
	struct region	*curregion;
	off_t		offset, size;
	int		chunkbytes = SUBBLOCKSIZE;
	char		resid[SECSIZE];
	writebuf_t	*wbuf;
	
	d_stream.zalloc   = (alloc_func)0;
	d_stream.zfree    = (free_func)0;
	d_stream.opaque   = (voidpf)0;
	d_stream.next_in  = 0;
	d_stream.avail_in = 0;
	d_stream.next_out = 0;

	err = inflateInit(&d_stream);
	CHECK_ERR(err, "inflateInit");

	/*
	 * Grab the header. It is uncompressed, and holds the real
	 * image size and the magic number. Advance the pointer too.
	 */
	blockhdr    = (blockhdr_t *) chunkbufp;
	chunkbufp  += DEFAULTREGIONSIZE;
	chunkbytes -= DEFAULTREGIONSIZE;
	
	switch (blockhdr->magic) {
	case COMPRESSED_V1:
	{
		static int didwarn;

		curregion = (struct region *)
			((struct blockhdr_V1 *)blockhdr + 1);
		if (dofill && !didwarn) {
			fprintf(stderr,
				"WARNING: old image file format, "
				"may not zero all unused blocks\n");
			didwarn = 1;
		}
		break;
	}

	case COMPRESSED_V2:
	case COMPRESSED_V3:
		imageversion = 2;
		curregion = (struct region *)
			((struct blockhdr_V2 *)blockhdr + 1);
		/*
		 * Extract relocation information
		 */
		getrelocinfo(blockhdr);
		break;

	default:
		fprintf(stderr, "Bad Magic Number!\n");
		exit(1);
	}

	/*
	 * Handle any lead-off free space
	 */
	if (imageversion > 1 && curregion->start > blockhdr->firstsect) {
		offset = sectobytes(blockhdr->firstsect);
		size = sectobytes(curregion->start - blockhdr->firstsect);
		if (dofill) {
			wbuf = alloc_writebuf(offset, size, 0, 1);
			dowrite_request(wbuf);
		} else
			totaledata += size;
	}
 
	/*
	 * Start with the first region. 
	 */
	offset = sectobytes(curregion->start);
	size   = sectobytes(curregion->size);
	assert(size > 0);
	curregion++;
	blockhdr->regioncount--;

	if (debug == 1)
		fprintf(stderr, "Decompressing: %14qd --> ", offset);

	wbuf = NULL;
	while (1) {
		/*
		 * Read just up to the end of compressed data.
		 */
		count              = blockhdr->size;
		blockhdr->size     = 0;
		d_stream.next_in   = chunkbufp;
		d_stream.avail_in  = count;
		chunkbufp	  += count;
		chunkbytes	  -= count;
		assert(chunkbytes >= 0);
	inflate_again:
		assert(wbuf == NULL);
		wbuf = alloc_writebuf(offset, OUTSIZE, 1, 1);

		/*
		 * Must operate on multiples of the sector size so first we
		 * restore any residual from the last decompression.
		 */
		if (ibleft)
			memcpy(wbuf->data, resid, ibleft);

		/*
		 * Adjust the decompression params to account for the resid
		 */
		d_stream.next_out  = &wbuf->data[ibleft];
		d_stream.avail_out = OUTSIZE - ibleft;

		/*
		 * Inflate a chunk
		 */
		err = inflate(&d_stream, Z_SYNC_FLUSH);
		if (err != Z_OK && err != Z_STREAM_END) {
			fprintf(stderr, "inflate failed, err=%d\n", err);
			exit(1);
		}

		/*
		 * Figure out how much valid data is in the buffer and
		 * save off any SECSIZE residual for the next round.
		 *
		 * Yes the ibsize computation is correct, just not obvious.
		 * The obvious expression is:
		 *	ibsize = (OUTSIZE - ibleft) - avail_out + ibleft;
		 * so ibleft cancels out.
		 */
		ibsize = OUTSIZE - d_stream.avail_out;
		count  = ibsize & ~(SECSIZE - 1);
		ibleft = ibsize - count;
		if (ibleft)
			memcpy(resid, &wbuf->data[count], ibleft);
		wbuf->size = count;

		while (count) {
			/*
			 * Move data into the output block only as far as
			 * the end of the current region. Since outbuf is
			 * same size as rdyblk->buf, its guaranteed to fit.
			 */
			if (count <= size) {
				dowrite_request(wbuf);
				wbuf = NULL;
				cc = count;
			} else {
				writebuf_t *wbtail;

				/*
				 * Data we decompressed belongs to physically
				 * distinct areas, we have to split the
				 * write up, meaning we have to allocate a
				 * new writebuf and copy the remaining data
				 * into it.
				 */
				wbtail = split_writebuf(wbuf, size, 1);
				dowrite_request(wbuf);
				wbuf = wbtail;
				cc = size;
			}

			if (debug == 2) {
				fprintf(stderr,
					"%12qd %8d %8d %12qd %10qd %8d %5d %8d"
					"\n",
					offset, cc, count, totaledata, size,
					ibsize, ibleft, d_stream.avail_in);
			}

			count  -= cc;
			size   -= cc;
			offset += cc;
			assert(count >= 0);
			assert(size  >= 0);

			/*
			 * Hit the end of the region. Need to figure out
			 * where the next one starts. If desired, we write
			 * a block of zeros in the empty space between this
			 * region and the next.
			 */
			if (size == 0) {
				off_t	    newoffset;
				writebuf_t *wbzero;

				/*
				 * No more regions. Must be done.
				 */
				if (!blockhdr->regioncount)
					break;

				newoffset = sectobytes(curregion->start);
				size      = sectobytes(curregion->size);
				assert(size);
				curregion++;
				blockhdr->regioncount--;
				assert((newoffset-offset) > 0);
				if (dofill) {
					wbzero = alloc_writebuf(offset,
							newoffset-offset,
							0, 1);
					dowrite_request(wbzero);
				} else
					totaledata += newoffset-offset;
				offset = newoffset;
				if (wbuf)
					wbuf->offset = newoffset;
			}
		}
		assert(wbuf == NULL);

		/*
		 * Exhausted our output buffer but still have more input in
		 * the current chunk, go back and deflate more from this chunk.
		 */
		if (d_stream.avail_in)
			goto inflate_again;

		/*
		 * All input inflated and all output written, done.
		 */
		if (err == Z_STREAM_END)
			break;

		/*
		 * We should never reach this!
		 */
		assert(1);
	}
	err = inflateEnd(&d_stream);
	CHECK_ERR(err, "inflateEnd");

	assert(wbuf == NULL);
	assert(blockhdr->regioncount == 0);
	assert(size == 0);
	assert(blockhdr->size == 0);

	/*
	 * Handle any trailing free space
	 */
	curregion--;
	if (imageversion > 1 &&
	    curregion->start + curregion->size < blockhdr->lastsect) {
		offset = sectobytes(curregion->start + curregion->size);
		size = sectobytes(blockhdr->lastsect -
				  (curregion->start + curregion->size));
		if (dofill) {
			wbuf = alloc_writebuf(offset, size, 0, 1);
			dowrite_request(wbuf);
		} else
			totaledata += size;
		offset += size;
	}
 
	if (debug == 1) {
		fprintf(stderr, "%14qd\n", offset);
	}
#ifndef FRISBEE
	else if (dots) {
		fprintf(stderr, ".");
		if (dotcol++ > 59) {
			struct timeval estamp;

			gettimeofday(&estamp, 0);
			estamp.tv_sec -= stamp.tv_sec;
			fprintf(stderr, "%4ld %13qd\n",
				estamp.tv_sec, totaledata);

			dotcol = 0;
		}
	}
#endif

	return 0;
}

void
writezeros(off_t offset, off_t zcount)
{
	size_t	zcc;

	assert((offset & (SECSIZE-1)) == 0);

#ifndef FRISBEE
	if (docrconly)
		nextwriteoffset = offset;
	else
#endif
	if (seekable) {
		/*
		 * We must always seek, even if offset == nextwriteoffset,
		 * since we are using pwrite.
		 */
		if (lseek(outfd, offset, SEEK_SET) < 0) {
			perror("lseek to write zeros");
			exit(1);
		}
		nextwriteoffset = offset;
	} else if (offset != nextwriteoffset) {
		fprintf(stderr, "Non-contiguous write @ %qu (should be %qu)\n",
			offset, nextwriteoffset);
		exit(1);
	}

	while (zcount) {
		if (zcount <= OUTSIZE)
			zcc = zcount;
		else
			zcc = OUTSIZE;
		
#ifndef FRISBEE
		if (docrconly)
			compute_crc(zeros, zcc, &crc);
		else
#endif
		if ((zcc = write(outfd, zeros, zcc)) != zcc) {
			if (zcc < 0) {
				perror("Writing Zeros");
			}
			exit(1);
		}
		zcount     -= zcc;
		totalrdata += zcc;
		nextwriteoffset += zcc;
	}
}

void
writedata(off_t offset, size_t size, void *buf)
{
	ssize_t	cc;

	/*	fprintf(stderr, "Writing %d bytes at %qd\n", size, offset); */

#ifndef FRISBEE
	if (docrconly) {
		compute_crc(buf, size, &crc);
		cc = size;
	} else
#endif
	if (seekable) {
		cc = pwrite(outfd, buf, size, offset);
	} else if (offset == nextwriteoffset) {
		cc = write(outfd, buf, size);
	} else {
		fprintf(stderr, "Non-contiguous write @ %qu (should be %qu)\n",
			offset, nextwriteoffset);
		exit(1);
	}
		
	if (cc != size) {
		if (cc < 0)
			perror("write error");
		else
			fprintf(stderr, "Short write!\n");
		exit(1);
	}
	nextwriteoffset = offset + cc;
	totalrdata += cc;
}

#include "sliceinfo.h"

static long long outputmaxsize = 0;

/*
 * Parse the DOS partition table to set the bounds of the slice we
 * are writing to. 
 */
int
readmbr(int slice)
{
	struct doslabel doslabel;
	int		cc;

	if (slice < 1 || slice > 4) {
		fprintf(stderr, "Slice must be 1, 2, 3, or 4\n");
 		return 1;
	}

	if ((cc = devread(outfd, doslabel.pad2, DOSPARTSIZE)) < 0) {
		perror("Could not read DOS label");
		return 1;
	}
	if (cc != DOSPARTSIZE) {
		fprintf(stderr, "Could not get the entire DOS label\n");
 		return 1;
	}
	if (doslabel.magic != BOOT_MAGIC) {
		fprintf(stderr, "Wrong magic number in DOS partition table\n");
 		return 1;
	}

	outputminsec  = doslabel.parts[slice-1].dp_start;
	outputmaxsec  = doslabel.parts[slice-1].dp_start +
		        doslabel.parts[slice-1].dp_size;
	outputmaxsize = (long long)sectobytes(outputmaxsec - outputminsec);

	if (debug) {
		fprintf(stderr, "Slice Mode: S:%d min:%ld max:%ld size:%qd\n",
			slice, outputminsec, outputmaxsec, outputmaxsize);
	}
	return 0;
}

int
fixmbr(int slice, int dtype)
{
	struct doslabel doslabel;
	int		cc;

	if (lseek(outfd, (off_t)0, SEEK_SET) < 0) {
		perror("Could not seek to DOS label");
		return 1;
	}
	if ((cc = devread(outfd, doslabel.pad2, DOSPARTSIZE)) < 0) {
		perror("Could not read DOS label");
		return 1;
	}
	if (cc != DOSPARTSIZE) {
		fprintf(stderr, "Could not get the entire DOS label\n");
 		return 1;
	}
	if (doslabel.magic != BOOT_MAGIC) {
		fprintf(stderr, "Wrong magic number in DOS partition table\n");
 		return 1;
	}

	if (doslabel.parts[slice-1].dp_typ != dostype) {
		doslabel.parts[slice-1].dp_typ = dostype;
		if (lseek(outfd, (off_t)0, SEEK_SET) < 0) {
			perror("Could not seek to DOS label");
			return 1;
		}
		cc = write(outfd, doslabel.pad2, DOSPARTSIZE);
		if (cc != DOSPARTSIZE) {
			perror("Could not write DOS label");
			return 1;
		}
		fprintf(stderr, "Set type of DOS partition %d to %d\n",
			slice, dostype);
	}
	return 0;
}

static struct blockreloc *reloctable;
static int numrelocs;
#ifndef linux
static void reloc_bsdlabel(struct disklabel *label, int reloctype);
#endif
static void reloc_lilo(void *addr, int reloctype, uint32_t size);
static void reloc_lilocksum(void *addr, uint32_t off, uint32_t size);

static void
getrelocinfo(blockhdr_t *hdr)
{
	struct blockreloc *relocs;

	if (reloctable) {
		free(reloctable);
		reloctable = NULL;
	}

	if ((numrelocs = hdr->reloccount) == 0)
		return;

	reloctable = malloc(numrelocs * sizeof(struct blockreloc));
	if (reloctable == NULL) {
		fprintf(stderr, "No memory for relocation table\n");
		exit(1);
	}

	relocs = (struct blockreloc *)
		((void *)&hdr[1] + hdr->regioncount * sizeof(struct region));
	memcpy(reloctable, relocs, numrelocs * sizeof(struct blockreloc));
}

static void
applyrelocs(off_t offset, size_t size, void *buf)
{
	struct blockreloc *reloc;
	off_t roffset;
	uint32_t coff;

	if (numrelocs == 0)
		return;

	offset -= sectobytes(outputminsec);

	for (reloc = reloctable; reloc < &reloctable[numrelocs]; reloc++) {
		roffset = sectobytes(reloc->sector) + reloc->sectoff;
		if (offset < roffset+reloc->size && offset+size > roffset) {
			/* XXX lazy: relocation must be totally contained */
			assert(offset <= roffset);
			assert(roffset+reloc->size <= offset+size);

			coff = (u_int32_t)(roffset - offset);
			if (debug > 1)
				fprintf(stderr,
					"Applying reloc type %d [%qu-%qu] "
					"to [%qu-%qu]\n", reloc->type,
					roffset, roffset+reloc->size,
					offset, offset+size);
			switch (reloc->type) {
			case RELOC_NONE:
				break;
#ifndef linux
			case RELOC_FBSDDISKLABEL:
			case RELOC_OBSDDISKLABEL:
				assert(reloc->size >= sizeof(struct disklabel));
				reloc_bsdlabel((struct disklabel *)(buf+coff),
					       reloc->type);
				break;
#endif
			case RELOC_LILOSADDR:
			case RELOC_LILOMAPSECT:
				reloc_lilo(buf+coff, reloc->type, reloc->size);
				break;
			case RELOC_LILOCKSUM:
				reloc_lilocksum(buf, coff, reloc->size);
				break;
			default:
				fprintf(stderr,
					"Ignoring unknown relocation type %d\n",
					reloc->type);
				break;
			}
		}
	}
}

#ifndef linux
static void
reloc_bsdlabel(struct disklabel *label, int reloctype)
{
	int i, npart;
	uint32_t slicesize;

	/*
	 * This relocation only makes sense in slice mode,
	 * i.e., we are installing a slice image into another slice.
	 */
	if (slice == 0)
		return;

	if (label->d_magic  != DISKMAGIC || label->d_magic2 != DISKMAGIC) {
		fprintf(stderr, "No disklabel at relocation offset\n");
		exit(1);
	}

	assert(outputmaxsize > 0);
	slicesize = bytestosec(outputmaxsize);

	/*
	 * Fixup the partition table.
	 */
	npart = label->d_npartitions;
	for (i = 0; i < npart; i++) {
		uint32_t poffset, psize;

		if (label->d_partitions[i].p_size == 0)
			continue;

		/*
		 * Don't mess with OpenBSD partitions 8-15 which map
		 * extended DOS partitions.  Also leave raw partition
		 * alone as it maps the entire disk (not just slice)
		 * and we don't know how big that is.
		 */
		if (reloctype == RELOC_OBSDDISKLABEL &&
		    (i == 2 || (i >= 8 && i < 16)))
			continue;

		/*
		 * Perform the relocation, making offsets absolute
		 */
		label->d_partitions[i].p_offset += outputminsec;

		poffset = label->d_partitions[i].p_offset;
		psize = label->d_partitions[i].p_size;

		/*
		 * Tweak sizes so BSD doesn't whine:
		 *  - truncate any partitions that exceed the slice size
		 *  - change RAW ('c') partition to match slice size
		 */
		if (poffset + psize > outputmaxsec) {
			fprintf(stderr, "WARNING: partition '%c' "
				"too large for slice, truncating\n", 'a' + i);
			label->d_partitions[i].p_size = outputmaxsec - poffset;
		} else if (i == RAW_PART && psize != slicesize) {
			assert(label->d_partitions[i].p_offset == outputminsec);
			fprintf(stderr, "WARNING: raw partition '%c' "
				"too small for slice, growing\n", 'a' + i);
			label->d_partitions[i].p_size = slicesize;
		}
	}
	label->d_checksum = 0;
	label->d_checksum = dkcksum(label);
}
#endif

#include "extfs/lilo.h"

static void
reloc_lilo(void *addr, int reloctype, uint32_t size)
{
	sectaddr_t *sect = addr;
	int i, count = 0;
	u_int32_t sector;

	switch (reloctype) {
	case RELOC_LILOSADDR:
		assert(size == 5);
		count = 1;
		break;
	case RELOC_LILOMAPSECT:
		assert(size == 512);
		count = MAX_MAP_SECT + 1;
		break;
	}

	for (i = 0; i < count; i++) {
		sector = getsector(sect);
		if (sector == 0)
			break;
		sector += outputminsec;
		putsector(sect, sector, sect->device, sect->nsect);
		sect++;
	}
}

void
reloc_lilocksum(void *addr, uint32_t off, uint32_t size)
{
	struct idtab *id;

	assert(size == 2);
	assert(off >= sizeof(struct idtab));
	addr += off;

	/*
	 * XXX total hack: reloc entry points to the end of the
	 * descriptor table.  We back up sizeof(struct idtab)
	 * and checksum that many bytes.
	 */
	id = (struct idtab *)addr - 1;
	id->sum = 0;
	id->sum = lilocksum((union idescriptors *)id, LILO_CKSUM);
}


#if !defined(CONDVARS_WORK) && !defined(FRISBEE)
#include <errno.h>

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
