#!/bin/bash

# (c) 2011 National ICT Australia
# christoph.dwertmann@nicta.com.au

# shrinks partition 1 and the file system in it to its minium size + 5%
# this will only work on ext2/ext3 partitions
# partition table entries 2-4 are deleted!
# the start position of partition 1 is not touched

die () {
    echo >&2 "$@"
    exit 1
}

[ "$#" -eq 1 ] || die "-> Please specify a disk (e.g. /dev/sda) as parameter. Only the first partition will be shrunk. All other partitions will be destroyed!"

DISK="$1"
PART="$11"

!(mount | grep $DISK) || die "-> One or more partitions of $DISK are mounted. Umount them and try again.";

echo "-> Checking for disk usage on $PART"
mkdir -p /mnt
mount $PART /mnt
# divide used space by total space
USAGE=`df | grep $DISK |  awk '{ print $3/$2 }'`
umount /mnt

if [[ "$USAGE" > "0.9" ]]; then
	echo "-> Partition is more than 90% full. Not shrinking it.";
	exit 0;
fi	

echo "-> Shrinking filesystem on $PART to minimum size"
touch /etc/mtab
e2fsck -fy $PART
tune2fs -O ^has_journal $PART
# take the minimum fs size, multiply by 4 (to convert to 1k blocks) and add 5% free space
NEWSIZE=`resize2fs -M $PART | grep "The filesystem on" | awk '{ print $7*4*1.05 }'`

echo "-> Removing partition table entries 2, 3 and 4"

SFDISK="sfdisk -q -L -uB -f"

$SFDISK -N2 $DISK >/dev/null <<P2
0,0
P2

$SFDISK -N3 $DISK >/dev/null <<P3
0,0
P3

$SFDISK -N4 $DISK >/dev/null <<P4
0,0
P4

echo "-> Shrinking partition $PART to minimum size + 5%"

$SFDISK -N1 $DISK >/dev/null <<P1
,$NEWSIZE
y
P1

# re-read partition table
sfdisk -R $DISK

echo "-> Growing filesystem on $PART to partition size"

resize2fs $PART
tune2fs -O has_journal $PART
tune2fs -i 0 -c 0 $PART

echo "-> Done"
