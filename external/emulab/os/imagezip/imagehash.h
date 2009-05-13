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
#define HASH_TYPE_RAW	3
