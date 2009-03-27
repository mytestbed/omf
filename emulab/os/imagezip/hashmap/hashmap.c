/*
 * Copyright (c) 2005, 2006 University of Utah and the Flux Group.
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

#include <sys/types.h>
#include <inttypes.h>
#include <stdlib.h>
#include <stdio.h>
#include <fcntl.h>
#include <string.h>
#include <errno.h>
#include <openssl/sha.h>
#include <openssl/md5.h>
#include <assert.h>
#include <sys/uio.h>
#include <unistd.h>
#ifdef HASHSTATS
#include <sys/time.h>
#endif

#include "sliceinfo.h"
#include "global.h"
#include "imagehdr.h"
#include "hashmap.h"
#include "imagehash.h"

//#define FOLLOW
#define HASH_FREE

/*
 * globals for fetching the HASHSTATS related information
 */
#if HASHSTATS
struct hashstats {
	uint32_t cur_allocated;	 /* allocated sectors in original */
	uint32_t orig_allocated; /* allocated sectors in current */
	uint32_t cur_only;	 /* sectors allocated only in current */
	uint32_t orig_only;	 /* sectors allocated only in original */
	uint32_t shared;	 /* sectors allocated in both */
	uint32_t unchanged;	 /* shared sectors that have not changed */
	uint32_t nocompare;	 /* sectors assumed different with no compare */
	uint32_t hash_compares;	 /* hash blocks compared */
	uint32_t hash_scompares; /* sectors compared */
	uint32_t hash_identical; /* hash blocks identical */
	uint32_t hash_sidentical;/* sectors identical */
	uint32_t gaps;		 /* hash ranges with free gaps */
	uint32_t gapsects;	 /* free sectors in gaps */
	uint32_t unchangedgaps;	 /* hash ranges with gaps that hash ok */
	uint32_t gapunchanged;	 /* unchanged free sectors in gaps */
	uint32_t gapnocompare;	 /* uncompared sectors in gaps */
	uint32_t fixup;		 /* uncompared due to fixup overlap */
} hashstats;

struct timeval time_orig_read, time_curr_read, time_hash,
	time_hash_and_cmp;
#endif
extern void	freeranges(struct range *);

/*
 * hash_free determines what we do when we have overlapping free blocks
 * within hash range -- 
 */
#ifdef HASH_FREE
int hash_free = 1;
#else
int hash_free = 0;
#endif

static char *hashfile;
static unsigned char *hashdata;
static unsigned int hashdatasize;

/*
 * time the operation, updating the global_v (of type 'struct timeval')
 * with the time diff.
 */
#ifdef HASHSTATS
#define TIMEOP(op, global_v) 	{			\
	struct timeval	st, et, t;			\
	gettimeofday(&st, NULL);			\
	(op);						\
	gettimeofday(&et, NULL);			\
	timersub(&et, &st, &t);				\
	timeradd(&(global_v), &t, &(global_v));		\
}
#else
#define TIMEOP(op, global_v)	(op);
#endif

#ifdef DEBUG
static char *
spewhash(unsigned char *h)
{
	static char hbuf[33];
	uint32_t *foo = (uint32_t *)h;

	snprintf(hbuf, sizeof hbuf, "%08x%08x%08x%08x",
		 foo[0], foo[1], foo[2], foo[3]);
	return hbuf;
}

static void
dumphash(struct hashinfo *hinfo)
{
	uint32_t i, total = 0;
	struct hashregion *reg;

	for (i = 0; i < hinfo->nregions; i++) {
		reg = &hinfo->regions[i];
		printf("[%u-%u]: chunk %d, hash %s\n", reg->region.start,
			       reg->region.start + reg->region.size - 1,
				       reg->chunkno, spewhash(reg->hash));
		total += reg->region.size;
	}
	printf("TOTAL = %u\n", total);
}
#endif

//#define READ_CACHE

/*
 * Read from infd, hash the contents and compare with the hash from sig file.
 * Optionally (READ_CACHE), read-ahead and cache the blocks
 */
static int
hash_and_cmp(int infd,
	     unsigned char *(*hashfunc)(const unsigned char *, unsigned long,
					unsigned char *),
	     int hashlen, struct hashregion *hashreg, int num_reg)
{
	unsigned char		*bp;
	size_t			count, byte_size;
	ssize_t			cc;
	off_t			byte_start, retval;
	unsigned char 		hash[HASH_MAXSIZE];
	struct region		hreg = hashreg->region;
	int			iretval;

	//printf("hash_and_cmp: in -- start = %u, size = %x, num_reg = %d.\n",
	//				hreg.start, hreg.size, num_reg);
#ifdef READ_CACHE
	static struct range	cache = { 0, 0, NULL, NULL };
	static char		*odata = NULL;
	/*
	 * We read the blocks here. try to optimize here by reading 
	 * as many contguous blocks as possible (by looking thru the
	 * hashregions) and store the cached data's range.
	 * all subsequent calls that can be served from this cache are served.
	 * when the first request outside this data comes, we purge the cache
	 * (since request comes sequentially), and fetch the next bunch of
	 * consecutive blocks....
	 */
	if (hreg.start + hreg.size <= cache.start + cache.size) {
		/*
		 * serve the request from the cache
		 */
		buf = cache.data + sectobytes((hreg.start - cache.start));

		//printf("hash_and_cmp: fetching from cache start = %d...\n",
		//		sectobytes((hreg.start - cache.start)));
	} else {
		int i;
		/*
		 * bad luck ! gotta hit the disk...
		 */
		//printf("hash_and_cmp: NOT in cache...\n");

		/*
		 * find the contiguous blocks
		 */
		cache.start = hreg.start;
		cache.size = hreg.size;
		for (i = 0; i < num_reg - 1; i++) {
			/*
			 * since there are NO overlaps in hashed blocks
			 * just check end points..
			 */
			if (hashreg[i].region.start + hashreg[i].region.size
						!= hashreg[i+1].region.start) {
				break;
			}

			/*
			 * voila ! contiguous...
			 */
			cache.size += hashreg[i+1].region.size;
		}
	
		byte_size = sectobytes(cache.size);
		byte_start = sectobytes(cache.start);

		if (cache.data) {
			free(cache.data);
		}
		cache.data = (unsigned char *) malloc(byte_size);
		if (!cache.data) {
			fprintf(stderr, "hash_and_cmp: unable to malloc !\n:");
			goto error;
		}
		bzero(cache.data, byte_size);

		//printf("hash_and_cmp: gonna fetch start = %d, size = %d\n",
		//				cache.start, cache.size);

		/*
		 * go fetch the blocks.
		 */
		retval = lseek(infd, byte_start, SEEK_SET);
	//	printf("BUG_DBG: hash_and_cmp(): retval = %ld,"
	//		" byte_start = %ld\n", retval, byte_start);
		if (retval < 0) {
			fprintf(stderr, "hash_and_cmp: lseek error !\n:");
			goto free_error;
		}

		count = byte_size;
		bp = cache.data;
		while (count) {
			TIMEOP(cc = read(infd, bp, count), time_curr_read);
			if (cc < 0) {
				perror("hash_and_cmp: read error -- ");
				goto free_error;
			}
			count -= cc;
			//printf("looping...%d %d\n", cc, count);
			bp += cc;
		}
		buf = cache.data;

	}
#else
	/*
	 * Read from the disk !
	 */
	byte_size = sectobytes(hreg.size);
	byte_start = sectobytes(hreg.start);
	assert(hreg.size <= hashdatasize);

	retval = lseek(infd, byte_start, SEEK_SET);
	if (retval < 0) {
		perror("hash_and_cmp: lseek error");
		return -1;
	}

	count = byte_size;
	bp = hashdata;
	while (count > 0) {
		TIMEOP(cc = read(infd, bp, count), time_curr_read);
		if (cc < 0) {
			perror("hash_and_cmp: read error");
			return -1;
		}
		if (cc == 0) {
			fprintf(stderr, "hash_and_cmp: unexpected EOF\n");
			return -1;
		}
		count -= cc;
		bp += cc;
	}
#endif

	/*
	 * now caculate the hash and compare it.
	 */
	TIMEOP(
	    (void)(*hashfunc)(hashdata, byte_size, hash),
	time_hash);

#if 0
	fprintf(stderr, "disk: %s\n", spewhash(hash));
	fprintf(stderr, "sig:  %s\n", spewhash(hashreg->hash));
#endif

	iretval = (memcmp(hashreg->hash, hash, hashlen) != 0);

#ifdef HASHSTATS
	hashstats.hash_compares++;
	hashstats.hash_scompares += hreg.size;
	if (!iretval) {
		hashstats.hash_identical++;
		hashstats.hash_sidentical += hreg.size;
	}
#endif

	return iretval;

#ifdef READ_CACHE
free_error:
	free(cache.data);
	cache.data = NULL;
error:
	cache.start = 0;
	cache.size = 0;
#endif
	return -1;
}

/*
 * add to tail, coalescing the blocks if they can be, else allocate a new node.
 */
static int
add_to_range(struct range **tailp, uint32_t start, uint32_t size)
{
	struct range *tail = *tailp;

	if (tail->start + tail->size == start) {
		/*
		 * coalesce...update the tail's size.
		 */
		tail->size += size;
	} else {
		struct range *tmp = malloc(sizeof(struct range));

		if (tmp == NULL) {
			fprintf(stderr, "add_to_range: malloc failed !\n");
			return -1;
		}

		tmp->start = start;
		tmp->size = size;
		tmp->next = NULL;

		tail->next = tmp;
		*tailp = tmp;
	}
	return 0;
}

/*
 * Read the hash info from a signature file into an array of hashinfo structs
 * We also record the maximum hash range size so we can size a static buffer
 * for IO.
 */
static int
readhashinfo(char *hfile, struct hashinfo **hinfop, uint32_t ssect)
{
	struct hashinfo		hi, *hinfo;
	int			fd, nregbytes, cc, i;

	fd = open(hfile, O_RDONLY);
	if (fd < 0) {
		perror(hfile);
		return -1;
	}
	cc = read(fd, &hi, sizeof(hi));
	if (cc != sizeof(hi)) {
		if (cc < 0)
			perror(hfile);
		else
			fprintf(stderr, "%s: too short\n", hfile);
		close(fd);
		return -1;
	}
	if (strcmp((char *)hi.magic, HASH_MAGIC) != 0 ||
	    hi.version != HASH_VERSION) {
		fprintf(stderr, "%s: not a valid signature file\n", hfile);
		return -1;
	}
	nregbytes = hi.nregions * sizeof(struct hashregion);
	hinfo = malloc(sizeof(hi) + nregbytes);
	if (hinfo == 0) {
		fprintf(stderr, "%s: not enough memory for info\n", hfile);
		return -1;
	}
	*hinfo = hi;
	cc = read(fd, hinfo->regions, nregbytes);
	if (cc != nregbytes) {
		free(hinfo);
		return -1;
	}

	for (i = 0; i < hinfo->nregions; i++) {
		struct hashregion *hreg = &hinfo->regions[i];
		if (hreg->region.size > hashdatasize)
			hashdatasize = hreg->region.size;
		hreg->region.start += ssect;
#ifdef HASHSTATS
		hashstats.orig_allocated += hreg->region.size;
#endif
	}
	close(fd);

	hashfile = hfile;
	hashdatasize = sectobytes(hashdatasize);
	hashdata = malloc(hashdatasize);
	if (hashdata == NULL) {
		fprintf(stderr, "%s: not enough memory for data buffer\n",
			hfile);
		return -1;
	}

#ifdef DEBUG
	//dumphash(hinfo);
#endif

	*hinfop = hinfo;
	return 0;
}


/*
 * Intersect the current allocated disk ranges (curranges) with the
 * hashinfo ranges read from the signature file (hfile).
 * Return the resulting range list.
 */
struct range *
hashmap_compute_delta(struct range *curranges, char *hfile, int infd,
		      uint32_t ssect)
{
	uint32_t		gapstart, gapsize, lastdrangeend = 0;
	unsigned int		hashlen;
	unsigned char		*(*hashfunc)(const unsigned char *,
					     unsigned long, unsigned char *);
	struct range		dummy_head, *range_tail;
	struct hashregion	*hreg, *ereg;
	char			*hashstr;
	struct hashinfo		*hinfo;
	struct range		*drange;
	int			retval, changed, gapcount;
	
	/*
	 * No allocated ranges, that was easy!
	 */
	if (curranges == NULL)
		return NULL;

	/*
	 * First we read the hashfile to get hash ranges and values
	 */
	retval = readhashinfo(hfile, &hinfo, ssect);
	if (retval < 0) {
		fprintf(stderr, "readhashinfo: failed !\n"
			" * * * Aborting * * *\n");
		exit(1);
	}

	/*
	 * Deterimine the hash function
	 */
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

	/*
	 * The new range list.  Use a dummy element as the head and
	 * keep track of the tail for easy appending.  The dummy element
	 * is initialized such that add_to_range() will not coalesce
	 * anything with it and it will remain distinct.
	 */
	dummy_head.start = ~0;
	dummy_head.size = 0;
	dummy_head.next = 0;
	range_tail = &dummy_head;

	/*
	 * Loop through all hash regions, comparing with the currently
	 * allocated disk regions.
	 */
	drange = curranges;
	ereg = hinfo->regions + hinfo->nregions;
	for (hreg = hinfo->regions; hreg < ereg; hreg++) {
		assert(drange && drange->size > 0);
#ifdef FOLLOW
		fprintf(stderr, "H: [%u-%u] start\n",
			hreg->region.start,
			hreg->region.start + hreg->region.size - 1);
		fprintf(stderr, "  D: [%u-%u] start\n",
			drange->start,
			drange->start + drange->size - 1);
#endif

		/*
		 * Any allocated ranges on disk that are before the
		 * hash range are newly allocated, and must be put in the image.
		 */
		while (drange &&
		       (drange->start + drange->size) <= hreg->region.start) {
#ifdef FOLLOW
			fprintf(stderr, "    D: [%u-%u] pre-hreg skip\n",
				drange->start,
				drange->start + drange->size - 1);
#endif
#ifdef HASHSTATS
			hashstats.cur_allocated += drange->size;
			hashstats.cur_only += drange->size;
#endif
			if (add_to_range(&range_tail,
					 drange->start, drange->size) < 0)
				goto error;

			lastdrangeend = drange->start + drange->size;
			drange = drange->next;
			assert(drange == NULL || drange->size > 0);
		}
		if (drange == NULL)
			break;
		assert(hreg->region.start < (drange->start + drange->size));

#ifdef FOLLOW
		fprintf(stderr, "  D: [%u-%u] after pre-hreg skip\n",
			drange->start,
			drange->start + drange->size - 1);
#endif

		/*
		 * Any allocated range in the original image that is below our
		 * first allocated range on the current disk can be ignored.
		 * (The blocks must have been deallocated.)
		 */

		if (hreg->region.start + hreg->region.size <= drange->start) {
#ifdef HASHSTATS
			hashstats.orig_only += hreg->region.size;
#endif
			continue;
		}

		/*
		 * Otherwise there is some overlap between the current drange
		 * and hreg.  To simplfy things, we split drange so that we can
		 * treat the portion of drange before the overlap seperately.
		 * thus aligning with hash boundaries
		 */
		assert(hreg->region.start + hreg->region.size > drange->start);
		assert(hreg->region.start < drange->start + drange->size);

		/*
		 * Any part of the drange that falls before the hreg is
		 * new data and needs to be in the image.
		 */
		if (drange->start < hreg->region.start) {
			uint32_t before = hreg->region.start - drange->start;
#ifdef HASHSTATS
			hashstats.cur_allocated += before;
			hashstats.cur_only += before;
#endif
			if (add_to_range(&range_tail,
					 drange->start, before) < 0)
				goto error;
			
#ifdef FOLLOW
			fprintf(stderr, "  D: [%u-%u]/[%u-%u] drange head split\n",
				drange->start,
				drange->start + before - 1,
				drange->start + before,
				drange->start + drange->size);
#endif
			/*
			 * Update drange with new start and size to account
			 * for the stuff we've taken off.  We continue
			 * processing with this new range.
			 */
			drange->start += before;
			drange->size -= before;
		}

		/*
		 * We have now isolated one or more dranges that are "covered"
		 * by the current hreg.  Here we might use the hash value
		 * associated with the hreg to determine whether the
		 * corresponding disk contents have changed.  If there is a
		 * single drange that exactly matches the hreg, then we
		 * obviously do this.  But what if there are gaps in the
		 * coverage, i.e., multiple non-adjacent dranges covered by
		 * the hreg?  This implies that not all blocks described by
		 * the original hash are still important in the current image.
		 * In fact there could be as little as a single disk block
		 * still valid for a very large hrange.
		 *
		 * In this case we can either blindly include the dranges
		 * in the merged list (hash_free==0), or we can go ahead and
		 * do the hash over the entire range (hash_free==1) on the
		 * chance that the blocks that are no longer allocated (the
		 * "gaps" between dranges) have not changed content and the
		 * hash will still match and thus we can avoid including the
		 * dranges in the merged list.  The latter is valid, but is
		 * it likely to pay off?  We will have to see.
		 */
		if (hash_free ||
		    (drange->start == hreg->region.start &&
		     drange->size >= hreg->region.size)) {

			/*
			 * XXX if there is a fixup, all bets are off
			 * (e.g., they might compare equal now, but not
			 * after the fixup).  Just force inclusion of all
			 * data.
			 *
			 * XXX we could do this on a drange by drange basis
			 * below, but I deem it not worth the trouble since
			 * all this code will be changing anyway.
			 */
			if (hasfixup(hreg->region.start, hreg->region.size)) {
				changed = 3;
#ifdef FOLLOW
				fprintf(stderr, "  H: [%u-%u] fixup overlap\n",
					hreg->region.start,
					hreg->region.start + hreg->region.size-1);
#endif
			} else {
				
				TIMEOP(
				       changed = hash_and_cmp(infd, hashfunc,
							      hashlen, hreg,
							      ereg - hreg),
				       time_hash_and_cmp);
				if (changed < 0)
					goto error;

#ifdef FOLLOW
				fprintf(stderr, "  H: [%u-%u] hash %s\n",
					hreg->region.start,
					hreg->region.start + hreg->region.size-1,
					changed ? "differs" : "matches");
#endif
			}
		} else {
			/*
			 * There is a gap in the dranges covered by the hreg.
			 * Just save all dranges covered by this hreg.
			 */
			changed = 2;
#ifdef FOLLOW
			fprintf(stderr, "  H: [%u-%u] no compare\n",
				hreg->region.start,
				hreg->region.start + hreg->region.size - 1);
#endif
		}

#ifdef HASHSTATS
		hashstats.shared += hreg->region.size;
		if (!changed)
			hashstats.unchanged += hreg->region.size;
		else if (changed > 1) {
			hashstats.nocompare += hreg->region.size;
			if (changed == 3)
				hashstats.fixup += hreg->region.size;
		}
		gapstart = hreg->region.start;
		gapsize = gapcount = 0;
#endif
		/*
		 * Loop through all dranges completely covered by the hreg
		 * and add them or skip them depending on changed.
		 */
		assert(drange &&
		       drange->start < hreg->region.start + hreg->region.size);
		while (drange &&
		       drange->start < hreg->region.start + hreg->region.size) {
			uint32_t curstart = drange->start;
			uint32_t curend = curstart + drange->size;
			uint32_t hregstart = hreg->region.start;
			uint32_t hregend = hregstart + hreg->region.size;

			/*
			 * There may be a final drange which crosses over the
			 * hreg end, in which case we split it, treating the
			 * initial part here, and leaving the rest for the next
			 * iteration.
			 */
			if (curend > hregend) {
				uint32_t after = curend - hregend;
#ifdef FOLLOW
				fprintf(stderr, "    D: [%u-%u]/[%u-%u] drange tail split\n",
					curstart,
					hregend - 1,
					hregend,
					curend - 1);
#endif

				drange->start = hregend;
				drange->size = after;

				curend = hregend;
			}

			assert(curstart >= hregstart);
			assert(curend <= hregend);

#ifdef FOLLOW
			fprintf(stderr, "    D: [%u-%u] drange covered\n",
				curstart,
				curend - 1);
#endif

#ifdef HASHSTATS
			/*
			 * Keep track of the gaps
			 */
			if (gapstart < curstart) {
#ifdef FOLLOW
				fprintf(stderr,
					"    G: [%u-%u]\n",
					gapstart, curstart - 1);
#endif
				gapsize += curstart - gapstart;
				gapcount++;
			}
			gapstart = curend;
			hashstats.cur_allocated += curend - curstart;
#endif
			if (changed) {
				/*
				 * add the overlapping region.
				 */
				if (add_to_range(&range_tail, curstart,
						 curend - curstart) < 0)
					goto error;

			}

			/*
			 * Unless we split the current entry, bump
			 * drange to the next entry.
			 */
			if (curstart == drange->start) {
				lastdrangeend = curend;
				drange = drange->next;
				assert(drange == NULL || drange->size > 0);
			}
		}

#ifdef HASHSTATS
		/*
		 * Check for an end gap
		 */
		if (gapstart < hreg->region.start + hreg->region.size) {
			uint32_t hregend =
				hreg->region.start + hreg->region.size;
#ifdef FOLLOW
			fprintf(stderr, "    G: [%u-%u]\n",
				gapstart, hregend - 1);
#endif
			gapsize += hregend - gapstart;
			gapcount++;
		}

		/*
		 * Properly account for gaps.
		 * Earlier we counted the gap as part of the shared
		 * space and as either unchanged or uncompared--adjust
		 * those counts now.
		 */
		if (gapcount) {
			hashstats.gaps++;

			/* note adjustment of counts set above */
			hashstats.shared -= gapsize;
			hashstats.gapsects += gapsize;
			if (!changed) {
				hashstats.unchanged -= gapsize;
				hashstats.unchangedgaps++;
				hashstats.gapunchanged += gapsize;
			} else if (changed > 1) {
				hashstats.nocompare -= gapsize;
				if (changed == 3)
					hashstats.fixup -= gapsize;
				hashstats.gapnocompare += gapsize;
			}
#ifdef FOLLOW
			fprintf(stderr, "  H: [%u-%u] %d/%d free\n",
				hreg->region.start,
				hreg->region.start + hreg->region.size - 1,
				gapsize, hreg->region.size);
#endif
		}
#endif
		if (drange == NULL)
			break;
		assert(drange->start >= hreg->region.start + hreg->region.size);
	}
	assert(drange == NULL || hreg == ereg);
	assert(lastdrangeend > 0);

	/*
	 * Remaining hash entries are ignored since they are deallocated
	 * space.  We do keep stats about them however.
	 */
#ifdef HASHSTATS
	while (hreg < ereg) {
		uint32_t size;

		/*
		 * If we ran out of dranges in the middle of an hreg,
		 * the rest of the hreg is deallocated.
		 */
		if (lastdrangeend > 0 &&
		    lastdrangeend <= hreg->region.start + hreg->region.size) {
			size = hreg->region.start + hreg->region.size -
				lastdrangeend;
#ifdef FOLLOW
			fprintf(stderr, "H: [%u-%u]/[",
				hreg->region.start,
				lastdrangeend - 1);
			if (size)
				fprintf(stderr, "%u-%u",
					lastdrangeend,
					hreg->region.start +
					hreg->region.size - 1);
			fprintf(stderr, "] split, tail skipped\n");
#endif
		} else {
			size = hreg->region.size;
#ifdef FOLLOW
			fprintf(stderr, "H: [%u-%u] skipped\n",
				hreg->region.start,
				hreg->region.start + hreg->region.size - 1);
#endif
		}
		hashstats.orig_only += size;

		lastdrangeend = 0;
		hreg++;
	}
#endif

	/*
	 * Remaining dranges are added to the changed blocks list.
	 */
	while (drange) {
		assert(hreg == ereg);
#ifdef HASHSTATS
		hashstats.cur_allocated += drange->size;
		hashstats.cur_only += drange->size;
#endif
		if (add_to_range(&range_tail, drange->start, drange->size) < 0)
			goto error;

		drange = drange->next;
		assert(drange == NULL || drange->size > 0);
	}

	return dummy_head.next;

error:
	freeranges(dummy_head.next);
	return NULL;
}

#include <sys/stat.h>

void
report_hash_stats(int pnum)
{
#ifdef HASHSTATS
	uint32_t b1, b2;
	double t;
	struct stat sb;

	fprintf(stderr,"\nHASH STATS:\n\n");

	fprintf(stderr, "Signature file:         %s ", hashfile);
	sb.st_mtime = 0;
	if (lstat(hashfile, &sb) >= 0 && S_ISLNK(sb.st_mode)) {
		char nbuf[128];
		int i;

		i = readlink(hashfile, nbuf, sizeof(nbuf));
		if (i > 0) {
			nbuf[i] = 0;
			fprintf(stderr, "-> %s ", nbuf);
		}
		stat(hashfile, &sb);
	}
	fprintf(stderr, "(%u)\n", (unsigned)sb.st_mtime);
	fprintf(stderr, "Partition:              %d\n", pnum);

	fprintf(stderr, "Max hash block size:    %u sectors\n\n",
		bytestosec(hashdatasize));
	fprintf(stderr, "Hash incomplete ranges: %d\n", hash_free);

	t = time_curr_read.tv_sec + (double)time_curr_read.tv_usec / 1000000.0;
	fprintf(stderr, "Disk read time:         %7.3f sec\n", t);

	t = time_hash.tv_sec + (double)time_hash.tv_usec / 1000000.0;
	fprintf(stderr, "Hash time:              %7.3f sec\n", t);

	t = time_hash_and_cmp.tv_sec +
		(double)time_hash_and_cmp.tv_usec / 1000000.0;
	fprintf(stderr, "Read+hash time:         %7.3f sec\n\n", t);

	b1 = hashstats.hash_compares;
	b2 = hashstats.hash_identical;
	fprintf(stderr, "Hash blocks compared:   %10u\n",
		b1);
	fprintf(stderr, "  Identical:            %10u (%.1f%%)\n",
		b2, ((double)b2 / b1) * 100.0);

	b1 = hashstats.hash_scompares;
	b2 = hashstats.hash_sidentical;
	fprintf(stderr, "Total sectors compared: %10u\n",
		b1);
	fprintf(stderr, "  Identical:            %10u (%.1f%%)\n\n",
		b2, ((double)b2 / b1) * 100.0);

	b1 = hashstats.orig_allocated;
	fprintf(stderr, "Original sectors:       %10u\n", b1);

	b1 = hashstats.cur_allocated;
	fprintf(stderr, "Current sectors:        %10u\n", b1);

	b1 = hashstats.shared;
	fprintf(stderr, "Common sectors:         %10u\n", b1);

	b1 = hashstats.orig_allocated;
	b2 = hashstats.orig_only + hashstats.gapsects;		
	fprintf(stderr, "Deleted from original:  %10u (%.1f%%)\n",
		b2, ((double)b2 / b1) * 100.0);

	b2 = hashstats.cur_only;
	fprintf(stderr, "Added to original:      %10u (%.1f%%)\n",
		b2, ((double)b2 / b1) * 100.0);

	b2 = (hashstats.shared - hashstats.unchanged);
	fprintf(stderr, "Modified from original: %10u (%.1f%%)\n\n",
		b2, ((double)b2 / b1) * 100.0);

	fprintf(stderr, "Hash blocks covering free sectors:   %u\n",
		hashstats.gaps);
	fprintf(stderr, "  Total free sectors covered:        %u\n",
		hashstats.gapsects);
	fprintf(stderr, "  Hash blocks compared identical:    %u\n",
		hashstats.unchangedgaps);
	fprintf(stderr, "  Free sectors compared identical:   %u\n",
		hashstats.gapunchanged);
	fprintf(stderr, "  Allocated sectors assumed changed: %u\n",
		hashstats.nocompare);
	fprintf(stderr, "    Assumed changed due to fixups:   %u\n",
		hashstats.fixup);

	fprintf(stderr,"\nEND HASH STATS\n");
#endif
}
