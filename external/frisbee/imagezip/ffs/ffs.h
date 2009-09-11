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
 * Glue for FreeBSD 5.x <ufs/ffs/fs.h>.  This version supports UFS2.
 */
typedef int64_t ufs_time_t;
typedef	int32_t	ufs1_daddr_t;
typedef	int64_t	ufs2_daddr_t;

#ifndef BBSIZE
#define	BBSIZE		8192
#endif
#ifndef MAXBSIZE
#define MAXBSIZE	65536
#endif

#include "fs.h"
#define FSTYPENAMES
#include "disklabel.h"
