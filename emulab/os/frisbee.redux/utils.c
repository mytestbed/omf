/*
 * Copyright (c) 2000-2007 University of Utah and the Flux Group.
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
 * Some simple common utility functions.
 */

#include <sys/types.h>
#include <ctype.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <string.h>
#include <errno.h>
#include <sys/time.h>
#include <sys/sysctl.h>
#include <assert.h>

#include "decls.h"
#include "utils.h"

/*
 * Return current time in a string printable format. Caller must absorb
 * the string. 
 */
char *
CurrentTimeString(void)
{
	static char	buf[32];
	time_t		curtime;
	static struct tm tm;
	
	time(&curtime);
	strftime(buf, sizeof(buf), "%T", localtime_r(&curtime, &tm));

	return buf;
}

/*
 * Determine a sleep time based on the resolution of the clock.
 * If doround is set, the provided value is rounded up to the next multiple
 * of the clock resolution.  If not, the value is returned untouched but
 * an optional warning is printed.
 *
 * Note that rounding is generally a bad idea.  Say the kernel is 1 usec
 * past system tick N (1 tick == 1000usec).  If we round a value of 1/2
 * tick up to 1 tick and then call sleep, the kernel will add our 1 tick
 * to the current value to get a time slightly past tick N+1.  It will then
 * round that up to N+2, so we effectively sleep almost two full ticks.
 * But if we don't round the tick, then adding that to the current time
 * might yield a value less than N+1, which will round up to N+1 and we
 * will at worst sleep one full tick.
 */
int
sleeptime(unsigned int usecs, char *str, int doround)
{
	static unsigned int clockres_us;
	int nusecs;

	if (clockres_us == 0) {
#ifndef linux
		struct clockinfo ci;
		int cisize = sizeof(ci);

		ci.hz = 0;
		if (sysctlbyname("kern.clockrate", &ci, &cisize, 0, 0) == 0 &&
		    ci.hz > 0)
			clockres_us = ci.tick;
		else
#endif
		{
			warning("cannot get clock resolution, assuming 100HZ");
			clockres_us = 10000;
		}

		if (debug)
			log("clock resolution: %d us", clockres_us);
	}
	nusecs = ((usecs + clockres_us - 1) / clockres_us) * clockres_us;
	if (doround) {
		if (nusecs != usecs && str != NULL)
			warning("%s: rounded to %d from %d "
				"due to clock resolution", str, nusecs, usecs);
	} else {
		if (nusecs != usecs && str != NULL) {
			warning("%s: may be up to %d (instead of %d) "
				"due to clock resolution", str, nusecs, usecs);
		}
		nusecs = usecs;
	}

	return nusecs;
}

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

/*
 * Sleep til indicated time.
 * Returns 0 if it did not sleep.
 */
int
sleeptil(struct timeval *nexttime)
{
	struct timeval curtime;
	struct timespec todo, left;

	gettimeofday(&curtime, 0);
	if (!pasttime(&curtime, nexttime)) {
		subtime(&curtime, nexttime, &curtime);
		todo.tv_sec = curtime.tv_sec;
		todo.tv_nsec = curtime.tv_usec * 1000;
		left.tv_sec = left.tv_nsec = 0;
		while (nanosleep(&todo, &left) != 0) {
			if (errno != EINTR) {
				log("nanosleep failed\n");
				exit(1);
			}
			todo = left;
			left.tv_sec = left.tv_nsec = 0;
		}
		return 1;
	}
	return 0;
}

void
BlockMapInit(BlockMap_t *blockmap, int block, int count)
{
	assert(block >= 0);
	assert(count > 0);
	assert(block < CHUNKSIZE);
	assert(block + count <= CHUNKSIZE);

	if (count == CHUNKSIZE) {
		memset(blockmap->map, ~0, sizeof(blockmap->map));
		return;
	}
	memset(blockmap->map, 0, sizeof(blockmap->map));
	BlockMapAdd(blockmap, block, count);
}

void
BlockMapAdd(BlockMap_t *blockmap, int block, int count)
{
	int i, off;

	assert(block >= 0);
	assert(count > 0);
	assert(block < CHUNKSIZE);
	assert(block + count <= CHUNKSIZE);

	i = block / CHAR_BIT;
	off = block % CHAR_BIT;
	while (count--) {
		blockmap->map[i] |= (1 << off);
		if (++off == CHAR_BIT) {
			i++;
			off = 0;
		}
	}
}

/*
 * Mark the specified block as allocated and return the old value
 */
int
BlockMapAlloc(BlockMap_t *blockmap, int block)
{
	int i, off;

	assert(block >= 0);
	assert(block < CHUNKSIZE);

	i = block / CHAR_BIT;
	off = block % CHAR_BIT;
	if ((blockmap->map[i] & (1 << off)) == 0) {
		blockmap->map[i] |= (1 << off);
		return 0;
	}
	return 1;
}

/*
 * Extract the next contiguous range of blocks, removing them from the map.
 * Returns the number of blocks extracted.
 */
int
BlockMapExtract(BlockMap_t *blockmap, int *blockp)
{
	int block, count, mask;
	int i, bit;

	assert(blockp != 0);

	/*
	 * Skip empty space at the front quickly
	 */
	for (i = 0; i < sizeof(blockmap->map); i++)
		if (blockmap->map[i] != 0)
			break;

	for (block = count = 0; i < sizeof(blockmap->map); i++) {
		for (bit = 0; bit < CHAR_BIT; bit++) {
			mask = 1 << bit;
			if ((blockmap->map[i] & mask) != 0) {
				blockmap->map[i] &= ~mask;
				if (count == 0)
					block = (i * CHAR_BIT) + bit;
				count++;
			} else {
				if (count > 0) {
					*blockp = block;
					return count;
				}
				if (blockmap->map[i] == 0)
					break;
			}
		}
	}
	if (count > 0)
		*blockp = block;

	return count;
}

/*
 * Return the number of blocks allocated in the range specified
 */
int
BlockMapIsAlloc(BlockMap_t *blockmap, int block, int count)
{
	int i, off, did = 0;
	char val;

	assert(block >= 0);
	assert(count > 0);
	assert(block < CHUNKSIZE);
	assert(block + count <= CHUNKSIZE);

	i = block / CHAR_BIT;
	off = block % CHAR_BIT;
	val = blockmap->map[i];
	while (count > 0) {
		/*
		 * Handle common aggregate cases
		 */
		if (off == 0 && count >= CHAR_BIT && (val == 0 || val == ~0)) {
			if (val)
				did += CHAR_BIT;
			count -= CHAR_BIT;
			off += CHAR_BIT;
		} else {
			if (val & (1 << off))
				did++;
			count--;
			off++;
		}
		if (off == CHAR_BIT && count > 0) {
			val = blockmap->map[++i];
			off = 0;
		}
	}
	return did;
}

void
BlockMapInvert(BlockMap_t *oldmap, BlockMap_t *newmap)
{
	int i;

	for (i = 0; i < sizeof(oldmap->map); i++)
		newmap->map[i] = ~(oldmap->map[i]);
}

int
BlockMapMerge(BlockMap_t *frommap, BlockMap_t *tomap)
{
	int i, bit, mask, did = 0;

	for (i = 0; i < sizeof(frommap->map); i++) {
		if (tomap->map[i] == ~0 || frommap->map[i] == tomap->map[i])
			continue;
		for (bit = 0; bit < CHAR_BIT; bit++) {
			mask = 1 << bit;
			if ((frommap->map[i] & mask) != 0 &&
			    (tomap->map[i] & mask) == 0) {
				tomap->map[i] |= mask;
				did++;
			}
		}
	}

	return did;
}

static void
bmfirstfunc(int chunk, int block, int count, void *arg)
{
	int *firstp = arg;

	if (*firstp == -1)
		*firstp = block;
}

int
BlockMapFirst(BlockMap_t *blockmap)
{
	int first = -1;

	(void) BlockMapApply(blockmap, 0, bmfirstfunc, &first);
	return first;
}

/*
 * Repeatedly apply the given function to each contiguous allocated range.
 * Returns number of allocated blocks processed.
 */
int
BlockMapApply(BlockMap_t *blockmap, int chunk,
	      void (*func)(int, int, int, void *), void *arg)
{
	int block, count, mask;
	int i, bit, val;
	int did = 0;

	block = count = 0;
	for (i = 0; i < sizeof(blockmap->map); i++) {
		val = blockmap->map[i];
		for (bit = 0; bit < CHAR_BIT; bit++) {
			mask = 1 << bit;
			if ((val & mask) != 0) {
				val &= ~mask;
				if (count == 0)
					block = (i * CHAR_BIT) + bit;
				count++;
			} else {
				if (count > 0) {
					if (func)
						func(chunk, block, count, arg);
					did += count;
					count = 0;
				}
				if (val == 0)
					break;
			}
		}
	}
	if (count > 0) {
		if (func)
			func(chunk, block, count, arg);
		did += count;
	}

	return did;
}

#ifdef STATS
void
ClientStatsDump(unsigned int id, ClientStats_t *stats)
{
	int seconds;

	switch (stats->version) {
	case 1:
		/* compensate for start delay */
		stats->u.v1.runmsec -= stats->u.v1.delayms;
		while (stats->u.v1.runmsec < 0) {
			stats->u.v1.runsec--;
			stats->u.v1.runmsec += 1000;
		}

		log("Client %u Performance:", id);
		log("  runtime:                %d.%03d sec",
		    stats->u.v1.runsec, stats->u.v1.runmsec);
		log("  start delay:            %d.%03d sec",
		    stats->u.v1.delayms/1000, stats->u.v1.delayms%1000);
		seconds = stats->u.v1.runsec;
		if (seconds == 0)
			seconds = 1;
		log("  real data written:      %qu (%qu Bps)",
		    stats->u.v1.rbyteswritten,
		    stats->u.v1.rbyteswritten/seconds);
		log("  effective data written: %qu (%qu Bps)",
		    stats->u.v1.ebyteswritten,
		    stats->u.v1.ebyteswritten/seconds);
		log("Client %u Params:", id);
		log("  chunk/block size:     %d/%d",
		    CHUNKSIZE, BLOCKSIZE);
		log("  chunk buffers:        %d",
		    stats->u.v1.chunkbufs);
		if (stats->u.v1.writebufmem)
			log("  disk buffering:       %dMB",
			    stats->u.v1.writebufmem);
		log("  readahead/inprogress: %d/%d",
		    stats->u.v1.maxreadahead, stats->u.v1.maxinprogress);
		log("  recv timo/count:      %d/%d",
		    stats->u.v1.pkttimeout, stats->u.v1.idletimer);
		log("  re-request delay:     %d",
		    stats->u.v1.redodelay);
		log("  writer idle delay:    %d",
		    stats->u.v1.idledelay);
		log("  randomize requests:   %d",
		    stats->u.v1.randomize);
		log("Client %u Stats:", id);
		log("  net thread idle/blocked:        %d/%d",
		    stats->u.v1.recvidles, stats->u.v1.nofreechunks);
		log("  decompress thread idle/blocked: %d/%d",
		    stats->u.v1.nochunksready, stats->u.v1.decompblocks);
		log("  disk thread idle:        %d",
		    stats->u.v1.writeridles);
		log("  join/request msgs:       %d/%d",
		    stats->u.v1.joinattempts, stats->u.v1.requests);
		log("  dupblocks(chunk done):   %d",
		    stats->u.v1.dupchunk);
		log("  dupblocks(in progress):  %d",
		    stats->u.v1.dupblock);
		log("  partial requests/blocks: %d/%d",
		    stats->u.v1.prequests, stats->u.v1.lostblocks);
		log("  re-requests:             %d",
		    stats->u.v1.rerequests);
		break;

	default:
		log("Unknown stats version %d", stats->version);
		break;
	}
}
#endif
