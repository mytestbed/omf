#!/bin/bash

# (c) 2011 National ICT Australia
# christoph.dwertmann@nicta.com.au

die () {
    echo >&2 "$@"
    exit 1
}

[ "$#" -eq 1 ] || die "-> Please specify a disk (e.g. /dev/sda) as parameter. Only the first partition will be grown. All other partitions will be destroyed!"

DISK="$1"
PART="$11"

!(mount | grep $DISK) || die "-> One or more partitions of $DISK are mounted. Umount them and try again.";

echo "01-> Checking disk and partition sizes"

# re-read partition table in case it has been changed by frisbee
sfdisk -R $DISK

CURSIZE=`sfdisk $PART -uB -s`
TOTALSIZE=`sfdisk $DISK -uB -s`
FIRSTBLOCK=`sfdisk $DISK -uB -l | grep $PART | awk '{ sub(/\+/,"");sub(/\-/,"");print $3 }'`
NEWSIZE=$((TOTALSIZE-FIRSTBLOCK-1))

if [ "$NEWSIZE" -le "$CURSIZE" ]; then
	echo "91-> Partition $PART already has the maximum size. Not growing it.";
	echo "92-> Done";
	exit 0;
fi

echo "02-> Removing partition table entries 2, 3 and 4"

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

echo "03-> Growing partition $PART to the outer end of the disk"

$SFDISK -N1 $DISK >/dev/null <<P1
,$NEWSIZE
y
P1

echo "04-> Growing filesystem on $PART to partition size"
touch /etc/mtab
echo "05-> Checking file system for errors"
e2fsck -fy $PART
echo "06-> Removing journal"
tune2fs -O ^has_journal $PART
echo "07-> Resize file system"
resize2fs $PART
echo "08-> Creating journal"
tune2fs -O has_journal $PART
echo "09-> Resetting file system check counter"
tune2fs -i 0 -c 0 $PART

echo "10-> Done"
