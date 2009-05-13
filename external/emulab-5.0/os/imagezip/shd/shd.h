/*
 * Copyright (c) 2005 University of Utah and the Flux Group.
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
 * XXX all this should come out of a standard include file, this is just
 * here to get everything to compile.
 */

#include <sys/ioctl.h>

struct shd_range {
	u_int32_t start;
	u_int32_t end;
};

struct shd_modinfo {
	int command;		/* init=1, data=2, deinit=3 */
	struct shd_range *buf;	/* range buffer */
	long bufsiz;		/* buffer size (in entries) */
	long retsiz;		/* size of returned data (in entries) */
};

struct shd_allocinfo {
	struct shd_range *buf;	/* range buffer */
	long bufsiz;		/* buffer size (in entries) */
};

#define SHDGETMODIFIEDRANGES  _IOWR('S', 29, struct shd_modinfo)
#define SHDSETALLOCATEDRANGES _IOWR('S', 30, struct shd_allocinfo)
