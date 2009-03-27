/*
 * Copyright (c) 2000-2005 University of Utah and the Flux Group.
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

#include <inttypes.h>

/*
 * Some of this comes from the BSD disklabel.h
 */

struct dospart {
	unsigned char	dp_flag;	/* bootstrap flags */
	unsigned char	dp_shd;		/* starting head */
	unsigned char	dp_ssect;	/* starting sector */
	unsigned char	dp_scyl;	/* starting cylinder */
	unsigned char	dp_typ;		/* partition type */
	unsigned char	dp_ehd;		/* end head */
	unsigned char	dp_esect;	/* end sector */
	unsigned char	dp_ecyl;	/* end cylinder */
	u_int32_t	dp_start;	/* absolute starting sector number */
	u_int32_t	dp_size;	/* partition size in sectors */
};

#define DOSPTYP_UNUSED		0	/* Unused */
#ifndef DOSPTYP_FAT12
#define	DOSPTYP_FAT12		1	/* FAT12 */
#endif
#ifndef DOSPTYP_FAT16
#define	DOSPTYP_FAT16		4	/* FAT16 */
#endif
#ifndef DOSPTYP_FAT16L
#define	DOSPTYP_FAT16L		6	/* FAT16, part >= 32MB */
#endif
#ifndef DOSPTYP_EXT
#define	DOSPTYP_EXT		5	/* DOS extended partition */
#endif
#ifndef DOSPTYPE_NTFS
#define DOSPTYP_NTFS    	7       /* Windows NTFS partition */
#endif
#ifndef DOSPTYP_FAT32
#define	DOSPTYP_FAT32		11	/* FAT32 */
#endif
#ifndef DOSPTYP_FAT32_LBA
#define	DOSPTYP_FAT32_LBA	12	/* FAT32, LBA */
#endif
#ifndef DOSPTYP_FAT16L_LBA
#define	DOSPTYP_FAT16L_LBA	14	/* FAT16, part >= 32MB, LBA */
#endif
#ifndef DOSPTYPE_EXT_LBA
#define	DOSPTYP_EXT_LBA		15	/* DOS extended, LBA partition */
#endif
#ifndef DOSPTYP_LINSWP
#define	DOSPTYP_LINSWP		0x82	/* Linux swap partition */
#endif
#ifndef DOSPTYP_LINUX
#define	DOSPTYP_LINUX		0x83	/* Linux partition */
#endif
#ifndef DOSPTYP_386BSD
#define DOSPTYP_386BSD	 	0xa5	/* Free/NetBSD */
#endif
#ifndef DOSPTYP_OPENBSD
#define DOSPTYP_OPENBSD 	0xa6	/* OpenBSD */
#endif

#define ISBSD(t)	((t) == DOSPTYP_386BSD || (t) == DOSPTYP_OPENBSD)
#define ISEXT(t)	((t) == DOSPTYP_EXT || (t) == DOSPTYP_EXT_LBA)
#define ISFAT(t)	\
	((t) == DOSPTYP_FAT12 || (t) == DOSPTYP_FAT16 || \
	 (t) == DOSPTYP_FAT16L || (t) == DOSPTYP_FAT32 || \
	 (t) == DOSPTYP_FAT32_LBA || (t) == DOSPTYP_FAT16L_LBA)

#define BOOT_MAGIC	0xAA55

#ifndef DOSBBSECTOR
#define DOSBBSECTOR	0
#endif
#ifndef DOSPARTOFF
#define DOSPARTOFF	446
#endif
#ifndef NDOSPART
#define NDOSPART	4
#endif
#define MAXSLICES	32 /* > 4 to allow for extended partition naming */

struct doslabel {
	char		align[sizeof(short)];	/* Force alignment */
	char		pad2[DOSPARTOFF];
	struct dospart	parts[NDOSPART];
	unsigned short  magic;
};
#define DOSPARTSIZE \
	(DOSPARTOFF + NDOSPART*sizeof(struct dospart) + sizeof(unsigned short))

struct slicemap {
	int	type;
	char	*desc;
	int	(*process)(int snum, int stype, u_int32_t start, u_int32_t size,
			   char *sname, int sfd);
};

#define SLICEMAP_PROCESS_PROTO(__process_fname__)	\
	int __process_fname__(int snum, int stype, u_int32_t start, \
		u_int32_t size, char *sname, int sfd)

/* 0 == false for all, ~0 == true for all, else true for those set */
typedef uint32_t partmap_t[MAXSLICES];

extern partmap_t ignore, forceraw;
