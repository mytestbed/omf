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
#include <stdlib.h>
#include <err.h>
#include <assert.h>
#include <string.h>
#include <sys/types.h>

#include "sliceinfo.h"
#include "global.h"
#include "imagehdr.h"
#include "lilo.h"

/*
 * Grok enough LILO to be able to ferret out and create relocs for
 * absolute block numbers.  In a LILO bootblock and map file.
 *
 * This has only been tested with LILO 21.4-4 created boot blocks
 * and will only work with linear or LBA32 addresses.
 */

static u_int32_t partoff, partsize;

static int readatsector(int fd, u_int32_t sect, void *buf, int size);
static void fixup_sector(u_int32_t poff, sectaddr_t *sect);
static void fixup_map(int fd, u_int32_t startsect);

#define FOFFSET(_b, _s, _f) \
	((u_int32_t)&((_s *)0)->_f + (u_int32_t)_b)

int
fixup_lilo(int slice, int stype, u_int32_t start, u_int32_t size,
	   char *sname, int infd, int *found)
{
	union bblock bblock;
	union idescriptors dtab;
	struct bb1 *bb;
	struct image *ip;
	u_int32_t s0, s1, s2, s4, poff;
	int cc, i;

	/*
	 * Check for compiler alignment errors
	 * LILO has some funky-sized structures (sectaddrs)
	 * that make me nervous...
	 */
	assert(sizeof(sectaddr_t) == SADDR_S_SIZE);
	assert(sizeof(struct bb1) == BB1_S_SIZE);
	assert(sizeof(union bblock) == BBLOCK_S_SIZE);
	assert(sizeof(struct image) == IMAGE_S_SIZE);
	assert(sizeof(struct idtab) == IDTAB_S_SIZE);
	assert(sizeof(union idescriptors) == IDESC_S_SIZE);
	assert(sizeof(union mapsect) == MSECT_S_SIZE);

	if (devlseek(infd, sectobytes(start), SEEK_SET) < 0) {
		warnx("Linux Slice %d: Could not seek to bootblock",
		      slice+1);
		return 1;
	}
	if ((cc = devread(infd, &bblock, sizeof(bblock))) < 0) {
		warn("Linux Slice %d: Could not read bootblock", slice+1);
		return 1;
	}
	if (cc != sizeof(bblock)) {
		warnx("Linux Slice %d: Truncated bootblock", slice+1);
		return 1;
	}

	bb = &bblock.bb1;
	if (strncmp(bb->sig, "LILO", 4) != 0) {
		*found = 0;
		return 0;
	}
	*found = 1;

	/*
	 * Only ever tested with stage 1 boot loader
	 */
	if (bb->stage != 1) {
		warnx("Linux Slice %d: no LILO relocs generated: "
		      "stage=%d, can only handle stage 1",
		      slice+1, bb->stage);
		return 0;
	}

	/*
	 * According to docs, the following sections are all part of the
	 * map file, in contiguous order:
	 *	default command line (1 sector)
	 *	image descriptors (2 sectors)
	 *	"zero" sector (1 sector)
	 *	keyboard map (1 sector)
	 */
	s0 = getsector(&bb->cmdline);
	s1 = getsector(&bb->idesc[0]);
	s2 = getsector(&bb->idesc[1]);
	s4 = getsector(&bb->keytab);
	if (s1 != s0+1 || s2 != s0+2 || s4 != s0+4) {
		warnx("Linux Slice %d: no LILO relocs generated: "
		      "map sectors out of order",
		      slice+1);
		return 0;
	}

	partoff = start;
	partsize = size;

	/*
	 * Read the image descriptor table and checksum
	 */
	if (readatsector(infd, s1, &dtab, sizeof(dtab)) != 0)
		return 1;

	if (lilocksum(&dtab, LILO_CKSUM) != 0) {
		warnx("Linux Slice %d: no LILO relocs generated: "
		      "bad checksum in descriptor table",
		      slice+1);
		return 0;
	}

	/*
	 * Fixup bootblock sector addresses
	 */
	poff = 0;
	fixup_sector(FOFFSET(poff, struct bb1, idesc[0]), &bb->idesc[0]);
	fixup_sector(FOFFSET(poff, struct bb1, idesc[1]), &bb->idesc[1]);
	fixup_sector(FOFFSET(poff, struct bb1, cmdline), &bb->cmdline);
	fixup_sector(FOFFSET(poff, struct bb1, keytab), &bb->keytab);
	if (bb->msglen > 0)
		fixup_sector(FOFFSET(poff, struct bb1, msg), &bb->msg);
	for (i = 0; i <= MAX_BOOT2_SECT; i++)
		fixup_sector(FOFFSET(poff, struct bb1, boot2[i]),
			     &bb->boot2[i]);

	/*
	 * Fixup the descriptor table
	 */
	poff = FOFFSET(sectobytes(s1-partoff), union idescriptors, idtab);
	ip = dtab.idtab.images;
	for (i = 0; i < MAX_IMAGE_DESC; i++) {
		if (*ip->name == '\0')
			break;
		if (debug > 1)
			fprintf(stderr, "  LILO parse: found image %s\n",
				ip->name);
		if (*(u_int32_t *)ip->rdsize != 0) {
			s0 = getsector(&ip->initrd);
			fixup_sector(FOFFSET(poff, struct idtab,
					     images[i].initrd), &ip->initrd);
			fixup_map(infd, s0);
		}
		s0 = getsector(&ip->start);
		fixup_sector(FOFFSET(poff, struct idtab, images[i].start),
			     &ip->start);
		fixup_map(infd, s0);
		ip++;
	}

	/*
	 * Ensure that the checksum is recomputed
	 * XXX we schedule it after the last entry in the table to make
	 * sure it triggers after all the sectaddr relocs.
	 */
	poff += sizeof(struct idtab);
	addfixup(sectobytes(partoff)+poff, sectobytes(partoff),
		 (off_t)2, &dtab.idtab.images[MAX_IMAGE_DESC],
		 RELOC_LILOCKSUM);

	return 0;
}

static int
readatsector(int fd, u_int32_t sect, void *buf, int size)
{
	assert(sect >= partoff);
	assert(sect+bytestosec(size) <= partoff+partsize);

	if (devlseek(fd, sectobytes(sect), SEEK_SET) < 0) {
		perror("LILO parse: sector seek");
		return 1;
	}
	if (devread(fd, buf, size) != size) {
		perror("LILO parse: sector read");
		return 1;
	}

	return 0;
}

/*
 * Create a fixup entry for a LILO sector address
 * poff is the offset of the address field from the beginning of the partition
 */
static void
fixup_sector(u_int32_t poff, sectaddr_t *sect)
{
	u_int32_t sector;
	sectaddr_t nsect;
	off_t boff;

	sector = getsector(sect);
	if (sector == 0)
		return;

	assert(sector >= partoff);
	assert(sector < partoff + partsize);

	if (debug > 1)
		fprintf(stderr, "  LILO parse: "
			"fixup sectaddr at poff %d: %d -> %d\n",
			poff, sector, sector-partoff);
	putsector(&nsect, sector-partoff, sect->device, sect->nsect);

	boff = sectobytes(partoff);
	addfixup(boff+poff, boff, (off_t)sizeof(nsect), &nsect,
		 RELOC_LILOSADDR);
}

static void
fixup_map(int fd, u_int32_t startsect)
{
	union mapsect mapsect;
	u_int32_t addr = 0, poff;
	int i, mapsectno = 0;
	off_t boff;

	boff = sectobytes(partoff);
	while (startsect != 0) {
		if (readatsector(fd, startsect, &mapsect, sizeof(mapsect)) != 0)
			exit(1);
		poff = sectobytes(startsect - partoff);
		for (i = 0; i <= MAX_MAP_SECT; i++) {
			addr = getsector(&mapsect.addr[i]);
			if (addr == 0)
				break;
			if (debug > 2)
				fprintf(stderr, "  LILO parse: "
					"fixup map sector %d/%d: %d -> %d\n",
					mapsectno, i, addr, addr-partoff);
			putsector(&mapsect.addr[i], addr-partoff,
				  mapsect.addr[i].device, mapsect.addr[i].nsect);
		}
		if (debug > 1)
			fprintf(stderr, "  LILO parse: "
				"fixup map sector at poff %d, %d sectaddrs\n",
				poff, i);

		/*
		 * Either we broke out because we hit the end (addr == 0)
		 * or we have finished the sector.  If the latter, we use
		 * the final sectaddr to locate the next sector of the map.
		 * In either case we create a fixup for the sector we just
		 * completed.
		 */
		addfixup(boff+poff, boff, (off_t)sizeof(mapsect),
			 &mapsect, RELOC_LILOMAPSECT);

		startsect = addr;
		mapsectno++;
	}
}
