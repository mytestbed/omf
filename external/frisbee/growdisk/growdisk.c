/*
 * Copyright (c) 2000-2003 University of Utah and the Flux Group.
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
 * "Grow" a testbed disk
 *
 * Used to expand the final (DOS) partition in a testbed image to
 * fill the remainder of the disk.  A typical testbed disk image
 * is sized to fit in the least-common-denominator disk we have,
 * currently 13GB.  This current image is laid out as:
 *
 *	       0 to       62: bootarea
 *	      63 to  6281414: FreeBSD (3GB)
 *	 6281415 to 12562829: Linux (3GB)
 *	12562830 to 12819869: Linux swap (128MB)
 *	12819870 to 26700029: unused
 *
 * for multi-OS disks, or:
 *
 *	       0 to       62: bootarea
 *	      63 to      N-1: some OS
 *	       N to 26700029: unused
 *
 * The goal of this program is to locate the final, unused partition and
 * resize it to match the actual disk size.  This program does *not* know
 * how to extend a filesystem, it only works on unused partitions and only
 * adjusts the size of the partition in the DOS partition table.
 *
 * The tricky part is determining how large the disk is.  Currently we do
 * this by reading the value out of a FreeBSD partition table using
 * DIOCGDINFO.  Even if there is no FreeBSD partition table, it should
 * attempt to fake one with a single partition whose size is the entire
 * disk.
 */

#include <stdio.h>
#include <unistd.h>
#include <fcntl.h>
#include <err.h>
#include <sys/disklabel.h>

struct diskinfo {
	char bootblock[512];
	int cpu, tpc, spt;
	unsigned long disksize;
	struct dos_partition *parts;
} diskinfo;

char optionstr[] =
"[-fhvW] [disk]\n"
"Create or extend a DOS partition to contain all trailing unallocated space\n"
"	-h print usage message\n"
"	-v verbose output\n"
"	-f output fdisk style partition entry\n"
"	   (sets slice type=FreeBSD if not already set)\n"
"	-N create a new partition to include the extra space (the default)\n"
"	-W actually change the partition table\n"
"	   (default is to just show what would be done)\n"
"	-X extend the final partition to include the extra space\n"
"	   (alternative to -N)\n"
"	[disk] is the disk special file to operate on\n"
"	   (default is /dev/ad0)";

#define usage()	errx(1, "Usage: %s %s\n", progname, optionstr);

void getdiskinfo(char *disk);
int setdiskinfo(char *disk);
int tweakdiskinfo(char *disk);
int showdiskinfo(char *disk);

char *progname;
int list = 1, verbose, fdisk, usenewpart = 1;

main(int argc, char *argv[])
{
	int ch;
	char *disk = "/dev/ad0";

	progname = argv[0];
	while ((ch = getopt(argc, argv, "fvhNWX")) != -1)
		switch(ch) {
		case 'v':
			verbose++;
			break;
		case 'f':
			fdisk++;
			break;
		case 'N':
			usenewpart = 1;
			break;
		case 'W':
			list = 0;
			break;
		case 'X':
			usenewpart = 0;
			break;
		case 'h':
		case '?':
		default:
			usage();
		}
	argc -= optind;
	argv += optind;
	if (argc == 1)
		disk = argv[0];

	getdiskinfo(disk);
	exit((list || fdisk) ? showdiskinfo(disk) : setdiskinfo(disk));
}

void
getdiskinfo(char *disk)
{
	int fd;
	struct disklabel label;
	unsigned long chs = 1;
	struct sector0 {
		char stuff[DOSPARTOFF];
		char parts[512-2-DOSPARTOFF];
		unsigned short magic;
	} *s0;


	memset(&diskinfo, 0, sizeof(diskinfo));
	fd = open(disk, O_RDONLY);
	if (fd < 0)
		err(1, "%s: opening for read", disk);
	if (ioctl(fd, DIOCGDINFO, &label) < 0)
		err(1, "%s: DIOCGDINFO", disk);
	diskinfo.cpu = label.d_ncylinders;
	chs *= diskinfo.cpu;
	diskinfo.tpc = label.d_ntracks;
	chs *= diskinfo.tpc;
	diskinfo.spt = label.d_nsectors;
	chs *= diskinfo.spt;
	diskinfo.disksize = label.d_secperunit;
	if (diskinfo.disksize < chs)
		errx(1, "%s: secperunit (%lu) < CxHxS (%lu)",
		     disk, diskinfo.disksize, chs);
	else if (diskinfo.disksize > chs) {
		if (verbose)
			warnx("%s: only using %lu of %lu reported sectors",
			      disk, chs, diskinfo.disksize);
		diskinfo.disksize = chs;
	}
	if (read(fd, diskinfo.bootblock, sizeof(diskinfo.bootblock)) < 0)
		err(1, "%s: error reading bootblock", disk);
	s0 = (struct sector0 *)diskinfo.bootblock;
	if (s0->magic != 0xAA55)
		errx(1, "%s: invalid bootblock", disk);
	diskinfo.parts = (struct dos_partition *)s0->parts;
	close(fd);
}

/*
 * Return non-zero if a partition was modified, zero otherwise.
 */
int
tweakdiskinfo(char *disk)
{
	int i, lastspace = NDOSPART, lastunused = NDOSPART;
	struct dos_partition *dp;
	long firstfree = -1;

	for (i = 0; i < NDOSPART; i++) {
		dp = &diskinfo.parts[i];
		if (dp->dp_typ != 0) {
			if (firstfree < 0 ||
			    dp->dp_start + dp->dp_size > firstfree) {
				lastspace = i;
				firstfree = dp->dp_start + dp->dp_size;
			}
		}
	}

	/*
	 * If wanting to extend the final used partition but there is
	 * no such partition, just create a new partition instead.
	 */
	if (!usenewpart && lastspace == NDOSPART)
		usenewpart = 1;

	/*
	 * No trailing free space, nothing to do
	 */
	if (firstfree >= diskinfo.disksize) {
		/*
		 * Warn about an allocated partition that exceeds the
		 * physical disk size.  This can happen if someone
		 * creates a disk image on a large disk and attempts
		 * to load it on a smaller one.  Not much we can do
		 * at this point except set off alarms...
		 */
		if (firstfree > diskinfo.disksize)
			warnx("WARNING! WARNING! "
			      "Allocated partitions too large for disk");
		return 0;
	}

	if (usenewpart) {
		int found = 0;

		/*
		 * Look for unused partitions already correctly defined.
		 * If we don't find one of those, we pick the first unused
		 * partition after the last used partition if possible.
		 * This prevents us from unintuitive behavior like defining
		 * partition 4 when no other partition is defined.
		 */
		for (i = NDOSPART-1; i >= 0; i--) {
			dp = &diskinfo.parts[i];
			if (dp->dp_typ != 0) {
				if (!found && lastunused != NDOSPART)
					found = 1;
			} else {
				if (dp->dp_start == firstfree &&
				    dp->dp_size == diskinfo.disksize-firstfree)
					return 0;
				/*
				 * Paranoia: avoid partially defined but
				 * unused partitions unless the start
				 * corresponds to the beginning of the
				 * unused space.
				 */
				if (!found &&
				    ((dp->dp_start == 0 && dp->dp_size == 0) ||
				     dp->dp_start == firstfree))
					lastunused = i;
			}
		}
	} else {
		/*
		 * Only change if:
		 *	- um...nothing else to check
		 *
		 * But tweak variables for the rest of this function.
		 */
		firstfree = diskinfo.parts[lastspace].dp_start;
		lastunused = lastspace;
	}

	if (lastunused == NDOSPART) {
		warnx("WARNING! No usable partition for free space");
		return 0;
	}
	dp = &diskinfo.parts[lastunused];

	if (fdisk) {
		printf("p %d %d %d %d\n",
		       lastunused+1, dp->dp_typ ? dp->dp_typ : DOSPTYP_386BSD,
		       dp->dp_start ? dp->dp_start : firstfree,
		       diskinfo.disksize-firstfree);
		return 1;
	}
	if (verbose || list) {
		if (dp->dp_start)
			printf("%s: %s size of partition %d "
			       "from %lu to %lu\n", disk,
			       list ? "would change" : "changing",
			       lastunused+1, dp->dp_size,
			       diskinfo.disksize-firstfree);
		else
			printf("%s: %s partition %d "
			       "as start=%lu, size=%lu\n", disk,
			       list ? "would define" : "defining",
			       lastunused+1, firstfree,
			       diskinfo.disksize-firstfree);
	}
	dp->dp_start = firstfree;
	dp->dp_size = diskinfo.disksize - firstfree;
	return 1;
}

int
showdiskinfo(char *disk)
{
	int i;
	struct dos_partition *dp;

	if (!fdisk) {
		printf("%s: %lu sectors (%dx%dx%d CHS)\n", disk,
		       diskinfo.disksize,
		       diskinfo.cpu, diskinfo.tpc, diskinfo.spt);
		for (i = 0; i < NDOSPART; i++) {
			dp = &diskinfo.parts[i];
			printf("  %d: start=%9lu, size=%9lu, type=0x%02x\n",
			       i+1, dp->dp_start, dp->dp_size, dp->dp_typ);
		}
	}
	if (!tweakdiskinfo(disk))
		return 1;
	return 0;
}

int
setdiskinfo(char *disk)
{
	int fd, cc;

	if (!tweakdiskinfo(disk)) {
		if (verbose)
			printf("%s: no change made\n", disk);
		return 0;
	}

	fd = open(disk, O_RDWR);
	if (fd < 0) {
		warn("%s: opening for write", disk);
		return 1;
	}
	cc = write(fd, diskinfo.bootblock, sizeof(diskinfo.bootblock));
	if (cc < 0) {
		warn("%s: bootblock write", disk);
		return 1;
	}
	if (cc != sizeof(diskinfo.bootblock)) {
		warnx("%s: partial write (%d != %d)\n", disk,
		      cc, sizeof(diskinfo.bootblock));
	}
	close(fd);
	if (verbose)
		printf("%s: partition table modified\n", disk);
	return 0;
}
