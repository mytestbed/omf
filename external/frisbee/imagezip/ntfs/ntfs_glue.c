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

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <assert.h>

#ifndef linux
#include <linux/fs.h>
#endif
#include "volume.h"
#include "inode.h"
#include "support.h" 
#include "attrib.h"
#include "runlist.h"
#include "dir.h"

#include "sliceinfo.h"
#include "global.h"

/********Code to deal with NTFS file system*************/
/* Written by: Russ Christensen <rchriste@cs.utah.edu> */

/**@bug If the Windows partition is only created in a part of a
 * primary partition created with FreeBSD's fdisk then the sectors
 * after the end of the NTFS partition and before the end of the raw
 * primary partition will not be marked as free space. */


struct ntfs_cluster;
struct ntfs_cluster {
	unsigned long start;
	unsigned long length;
	struct ntfs_cluster *next;
};

static __inline__ int
ntfs_isAllocated(char *map, __s64 pos)
{
	int result;
	char unmasked;
	char byte;
	short shift;
	byte = *(map+(pos/8));
	shift = pos % 8;
	unmasked = byte >> shift;
	result = unmasked & 1;
	assert((result == 0 || result == 1) &&
	       "Programming error in statement above");
	return result;
}

static void
ntfs_addskips(ntfs_volume *vol,struct ntfs_cluster *free,u_int32_t offset)
{
	u_int8_t sectors_per_cluster;
	struct ntfs_cluster *cur;
	int count = 0;
	sectors_per_cluster = vol->cluster_size / vol->sector_size;
	if(debug) {
		fprintf(stderr,"sectors per cluster: %d\n",
			sectors_per_cluster);
		fprintf(stderr,"offset: %d\n", offset);
	}
	for(count = 0, cur = free; cur != NULL; cur = cur->next, count++) {
		if(debug > 1) {
			fprintf(stderr, "\tGroup:%-10dCluster%8li, size%8li\n",
				count, cur->start,cur->length);
		}
		addskip(cur->start*sectors_per_cluster + offset,
			cur->length*sectors_per_cluster);
	}
}

static int
ntfs_freeclusters(struct ntfs_cluster *free)
{
	int total;
	struct ntfs_cluster *cur;
	for(total = 0, cur = free; cur != NULL; cur = cur->next)
		total += cur->length;
	return total;
}

/* The calling function owns the pointer returned.*/
static void *
ntfs_read_data_attr(ntfs_attr *na)
{
	void  *result;
	int64_t pos;
	int64_t tmp;
	int64_t amount_needed;
	int   count;

	/**ntfs_attr_pread might actually read in more data than we
	 * ask for.  It will round up to the nearest sector boundry
	 * so make sure we allocate enough memory.*/
	amount_needed = na->data_size - (na->data_size % secsize) + secsize;
	assert(amount_needed > na->data_size && amount_needed % secsize == 0
	       && "amount_needed is rounded up to sector size multiple");
	if(!(result = malloc(amount_needed))) {
		perror("Out of memory!\n");
		exit(1);
	}
	pos = 0;
	count = 0;
	while(pos < na->data_size) {
		tmp = ntfs_attr_pread(na,pos,na->data_size - pos,result+pos);
		if(tmp < 0) {
			perror("ntfs_attr_pread failed");
			exit(1);
		}
		assert(tmp != 0 && "Not supposed to happen error!  "
		       "Either na->data_size is wrong or there is another "
		       "problem");
		assert(tmp % secsize == 0 && "Not supposed to happen");
		pos += tmp;
	}
#if 0 /*Turn on if you want to look at the free list directly*/
	{
		int fd;

		fprintf(stderr, "Writing ntfs_free_bitmap.bin\n");
		if((fd = open("ntfs_free_bitmap.bin",
			      O_WRONLY | O_CREAT | O_TRUNC)) < 0) {
			perror("open ntfs_free_bitmap.bin failed\n");
			exit(1);
		}
		if(write(fd, result, na->data_size) != na->data_size) {
			perror("writing free space bitmap.bin failed\n");
			exit(1);
		}
		close(fd);
		fprintf(stderr, "Done\n");
	}
#endif
	return result;
}

static struct ntfs_cluster *
ntfs_compute_freeblocks(ntfs_attr *na, void *cluster_map, __s64 num_clusters)
{
	struct ntfs_cluster *result;
	struct ntfs_cluster *curr;
	struct ntfs_cluster *tmp;
	__s64 pos = 1;
	int total_free = 0;
	result = curr = NULL;
	assert(num_clusters <= na->data_size * 8 && "If there are more "
	       "clusters than bits in the free space file then we have a "
	       "problem.  Fewer clusters than bits is okay.");
	if(debug)
		fprintf(stderr,"num_clusters==%qd\n",num_clusters);
	while(pos < num_clusters) {
		if(!ntfs_isAllocated(cluster_map,pos++)) {
			curr->length++;
			total_free++;
		}
		else {
			while(ntfs_isAllocated(cluster_map,pos)
			      && pos < num_clusters) {
				++pos;
			}
			if(pos >= num_clusters) break;
			if(!(tmp = malloc(sizeof(struct ntfs_cluster)))) {
				perror("clusters_free: Out of memory");
				exit(1);
			}
			if(curr) {
				curr->next = tmp;
				curr = curr->next;
			} else
				result = curr = tmp;
			curr->start = pos;
			curr->length = 0;
			curr->next = NULL;
		}
	}
	if(debug)
		fprintf(stderr, "total_free==%d\n",total_free);
	return result;
}

/*Add the blocks used by filename to the free list*/
void
ntfs_skipfile(ntfs_volume *vol, char *filename, u_int32_t offset)
{
	u_int8_t sectors_per_cluster;
	ntfs_inode *ni, *ni_root;
	ntfs_attr *na;
	MFT_REF File;
	runlist_element *rl;
	int ulen;
	uchar_t *ufilename;
	int i;
	int amount_skipped;

	/*Goal: Get MFT_REF for filename before we can call ntfs_inode_open
	        on the file.*/
	if(!(ni_root = ntfs_inode_open(vol, FILE_root))) {
		perror("Opening file $ROOT failed\n");
		ntfs_umount(vol,TRUE);
		exit(1);
	}
	/* Subgoal: get the uchar_t name for filename */
	ufilename = malloc(sizeof(uchar_t)*(strlen(filename)+1));
	if(!ufilename) {
		fprintf(stderr, "Out of memory\n");
		exit(1);
	}
	bzero(ufilename,sizeof(uchar_t)*strlen(filename)+1);
	ulen = ntfs_mbstoucs(filename, &ufilename, strlen(filename)+1);
	if(ulen == -1) {
		perror("ntfs_mbstoucs failed");
		exit(1);
	}
	File = ntfs_inode_lookup_by_name(ni_root, ufilename, ulen);
	if(IS_ERR_MREF(File)) {
		if (debug > 1) {
			fprintf(stderr, "%s does not exist so there is no need "
				"to skip the file.\n", filename);
		}
		return;
	}
  	free(ufilename);
	ufilename = NULL;
	if(debug > 1 ) fprintf(stderr,"vol->nr_mft_records==%lld\n",
			       vol->nr_mft_records);
	/*Goal: Skip the file*/
	if(!(ni = ntfs_inode_open(vol, File))) {
	  perror("calling ntfs_inode_open (0)");
	  ntfs_umount(vol,TRUE);
	  exit(1);
	}
	if(!(na = ntfs_attr_open(ni, AT_DATA, NULL, 0))) {
		perror("Opening attribute $DATA failed\n");
		ntfs_umount(vol,TRUE);
		exit(1);
	}
	assert(NAttrNonResident(na) && "You are trying to skip a file that is "
	       "small enough to be resident inside the Master File Table. "
	       "This is a bit silly.");
	/*Goal: Find out what clusters on the disk are being used by filename*/
	sectors_per_cluster = vol->cluster_size / vol->sector_size;
	if(!(rl = ntfs_attr_find_vcn(na, 0))) {
	    perror("Error calling ntfs_attr_find_vcn");
	    exit(1);
	}
	amount_skipped = 0;
	for(i=0; rl[i].length != 0; i++) {
		if (rl[i].lcn == LCN_HOLE) {
		    if (debug > 1) {
			fprintf(stderr, "LCN_HOLE\n");
		    }
		    continue;
		}
		if (rl[i].lcn == LCN_RL_NOT_MAPPED) {
		    /* Pull in more of the runlist because the NTFS library
		       might not pull in the entire runlist when you ask
		       for it.  When I asked the NTFS library folks why they
		       do this they said it was for performance reasons. */
		    if (debug > 1) {
			fprintf(stderr, "LCN_RL_NOT_MAPPED\n");
		    }
		    if (ntfs_attr_map_runlist(na, rl[i].vcn) == -1) {
			perror("ntfs_attr_map_runlist failed\n");
			exit(1);
		    } else {
			rl = ntfs_attr_find_vcn(na, 0);
			/* There *might* be a memory leak here.  I don't
			   know if rl needs to be freed by us or not. */
			if(!rl) {
			    perror("Error calling ntfs_attr_find_vcn");
			    exit(1);
			}
			/*retry*/
			--i;
			continue;
		    }
		}
		if (debug > 1) {
		    fprintf(stderr, "For file %s skipping:%lld length:%lld\n",
			    filename,
			    (long long int)rl[i].lcn*sectors_per_cluster +
			    offset,
			    (long long int)rl[i].length*sectors_per_cluster);
		}
		assert(rl[i].length > 0 && "Programming error");
		assert(rl[i].lcn > 0 &&
		       "Programming error: Not catching NTFS Lib error value");
		amount_skipped += rl[i].length*sectors_per_cluster;
		addskip(rl[i].lcn*sectors_per_cluster + offset,
			rl[i].length*sectors_per_cluster);
	}
	if (debug) {
	    fprintf(stderr, "For NTFS file %s skipped %d bytes\n", filename,
		    amount_skipped*512);
	}
}

/*
 * Primary function to call to operate on an NTFS slice.
 */
int
read_ntfsslice(int slice, int stype, u_int32_t start, u_int32_t size,
	       char *openname, int infd)
{
	ntfs_inode     *ni_bitmap;
	ntfs_attr      *na_bitmap;
	void           *buf;
	struct ntfs_cluster *cfree;
  	struct ntfs_cluster *tmp;
	char           *name;
	ntfs_volume    *vol;

	/* Check to make sure the types the NTFS lib defines are what they
	   claim*/
	assert(sizeof(s64) == 8);
	assert(sizeof(s32) == 4);
	assert(sizeof(u64) == 8);
	assert(sizeof(u32) == 4);
	/*
	 * The NTFS library needs the /dev name of the partition to examine.
	 */
	if (slice < 0)
		name = openname;
	else
		name = slicename(slice, start, size, DOSPTYP_NTFS);
	if (name == NULL) {
		fprintf(stderr,
			"Could not locate special file for NTFS slice %d\n",
			slice+1);
		return 1;
	}
	if (debug)
		fprintf(stderr, "Using %s for NTFS slice %d\n", name, slice+1);
	/*The volume must be mounted to find out what clusters are free*/
	if(!(vol = ntfs_mount(name, MS_RDONLY))) {
		perror(name);
		fprintf(stderr, "Failed to read superblock information.  "
			"Not a valid NTFS partition\n");
		return 1;
	}
	/*A bitmap of free clusters is in the $DATA attribute of the
	 *  $BITMAP file*/
	if(!(ni_bitmap = ntfs_inode_open(vol, FILE_Bitmap))) {
		perror("Opening file $BITMAP failed\n");
		ntfs_umount(vol, TRUE);
		return 1;
	}
	if(!(na_bitmap = ntfs_attr_open(ni_bitmap, AT_DATA, NULL, 0))) {
		perror("Opening attribute $DATA failed\n");
		return 1;
	}
	buf = ntfs_read_data_attr(na_bitmap);
	cfree = ntfs_compute_freeblocks(na_bitmap,buf,vol->nr_clusters);
	ntfs_addskips(vol,cfree,start);
	if(debug > 1) {
		fprintf(stderr, "  P%d (NTFS v%u.%u)\n",
			slice + 1 /* DOS Numbering */,
			vol->major_ver,vol->minor_ver);
		fprintf(stderr, "        %s",name);
		fprintf(stderr, "      start %10d, size %10d\n", start, size);
		fprintf(stderr, "        Sector size: %u, Cluster size: %u\n",
			vol->sector_size, vol->cluster_size);
		fprintf(stderr, "        Volume size in clusters: %qd\n",
			vol->nr_clusters);
		fprintf(stderr, "        Free clusters:\t\t %u\n",
			ntfs_freeclusters(cfree));
	}

      	ntfs_skipfile(vol, "pagefile.sys", start);
      	ntfs_skipfile(vol, "hiberfil.sys", start);

	/*We have the information we need so unmount everything*/
	ntfs_attr_close(na_bitmap);
	if(ntfs_inode_close(ni_bitmap)) {
		perror("ntfs_close_inode ni_bitmap failed");
		return 1;
	}
	if(ntfs_umount(vol,FALSE)) {
		perror("ntfs_umount failed");
		return 1;
	}
	/*Free NTFS malloc'd memory*/
	assert(buf && "Programming Error, buf should be freed here");
	free(buf);
	assert(cfree && "Programming Error, "
	       "'struct cfree' should be freed here");
	while(cfree) {
		tmp = cfree->next;
		free(cfree);
		cfree = tmp;
	}
	return 0; /*Success*/
}
