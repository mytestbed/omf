/*
 * Copyright (c) 2000-2004 University of Utah and the Flux Group.
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
 * LILO-based constants.
 */
#define MAX_BOOT2_SECT	10
#define MAX_IMAGE_DESC	19
#define MAX_MAP_SECT	101

/*
 * Essential lilo data structs
 */

/*
 * Sector addresses.
 * These are the absolute values that must be relocated when moving
 * a bootable partition.  Is there an LBA form?
 */
typedef struct sectaddr {
	u_int8_t sector;
	u_int8_t track;
	u_int8_t device;		/* + flags, see below */
	u_int8_t head;
	u_int8_t nsect;
} sectaddr_t;
#define SADDR_S_SIZE	5

/* flags encoded in device */
#define HARD_DISK	0x80	/* not a floppy */
#define LINEAR_ADDR	0x40	/* mark linear address */
#define LBA32_ADDR	0x20    /* mark lba 32-bit address */
#define LBA32_NOCOUNT   0x10    /* mark address with count absent */
#define DEVFLAGS	0xF0

struct bb1 {
	u_int8_t jumpinst[6];
	char sig[4];		/* LILO */
	u_int16_t stage;		/* 1 -- stage1 loader */
	u_int16_t version;
	u_int16_t timeout;
	u_int16_t delay;
	u_int8_t port, portparams;
	u_int32_t timestamp;
	sectaddr_t idesc[2];	/* image descriptors */
	sectaddr_t cmdline;	/* command line (max 1 sector?) */
	u_int8_t prompt;
	u_int16_t msglen;
	sectaddr_t msg;		/* "initial greeting message" */
	sectaddr_t keytab;	/* "keyboard translation table" */
	sectaddr_t boot2[MAX_BOOT2_SECT+1]; /* 2nd stage boot sectors */
};
#define BB1_S_SIZE	108

struct bb2 {
	u_int8_t jumpinst[6];
	char sig[4];		/* LILO */
	u_int16_t stage;		/* 2 -- stage2 loader */
	u_int16_t version;
};

struct bb10 {
	u_int8_t jumpinst[6];
	char sig[4];		/* LILO */
	u_int16_t stage;		/* 0x10 -- chain loader */
	u_int16_t version;
	u_int16_t offset;
	u_int8_t drive, head;
	u_int16_t drivemap;
	u_int8_t parttab[16*4];
};

union bblock {
	struct bb1 bb1;
	struct bb2 bb2;
	struct bb10 bb10;
	char data[1*512];
};
#define BBLOCK_S_SIZE	512

/*
 * Image descriptors
 */
struct image {
	char name[16];
	char passwd[16];
	u_int16_t rdsize[2];
	sectaddr_t initrd;
	sectaddr_t start;
	u_int16_t spage, flags, vgamode;
};
#define IMAGE_S_SIZE	52

struct idtab {
	u_int16_t sum;
	struct image images[MAX_IMAGE_DESC];
};
#define IDTAB_S_SIZE	990

union idescriptors {
	struct idtab idtab;
	char data[2*512];
};
#define IDESC_S_SIZE	1024

/*
 * Map sectors
 */
union mapsect {
	sectaddr_t addr[MAX_MAP_SECT+1];
	char data[512];
};
#define MSECT_S_SIZE	512

static __inline u_int32_t
getsector(sectaddr_t *sect)
{
	int flags = (sect->device & DEVFLAGS) & ~HARD_DISK;
	u_int32_t sector = 0;

	if (sect->device == 0 && sect->nsect == 0 &&
	    sect->head == 0 && sect->track == 0 && sect->sector == 0)
		return 0;

	/* XXX */
	if (flags == 0) {
		fprintf(stderr, "LILO parse: no can do CHS addresses!\n");
		return 0;
	}

	if (flags & LINEAR_ADDR) {
		sector |= sect->head << 16;
		sector |= sect->track << 8;
		sector |= sect->sector;
	} else {
		if (flags & LBA32_NOCOUNT)
			sector |= sect->nsect << 24;
		sector |= sect->head << 16;
		sector |= sect->track << 8;
		sector |= sect->sector;
	}

	return sector;
}

static __inline void
putsector(sectaddr_t *sect, u_int32_t sector, int device, int nsect)
{
	int flags = (device & DEVFLAGS) & ~HARD_DISK;

	sect->device = device;
	sect->nsect = nsect;
	if (flags & LINEAR_ADDR) {
		sect->head = (sector >> 16) & 0xFF;
		sect->track = (sector >> 8) & 0xFF;
		sect->sector = sector & 0xFF;
	} else {
		if (flags & LBA32_NOCOUNT)
			sect->nsect = (sector >> 24) & 0xFF;
		sect->head = (sector >> 16) & 0xFF;
		sect->track = (sector >> 8) & 0xFF;
		sect->sector = sector & 0xFF;
	}
}

#define LILO_CKSUM	0xabcd

static __inline uint16_t
lilocksum(union idescriptors *idp, uint16_t sum)
{
	uint16_t *up = (uint16_t *)idp;
	uint16_t *ep = (uint16_t *)(idp + 1);
	while (up < ep)
		sum ^= *up++;
	return sum;
}

