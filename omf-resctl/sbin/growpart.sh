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

echo "-> Checking disk and partition sizes"

# re-read partition table in case it has been changed by frisbee
sfdisk -R $DISK

CURSIZE=`sfdisk $PART -uB -s`
TOTALSIZE=`sfdisk $DISK -uB -s`
FIRSTBLOCK=`sfdisk $DISK -uB -l | grep $PART | awk '{ sub(/\+/,"");sub(/\-/,"");print $3 }'`
NEWSIZE=$((TOTALSIZE-FIRSTBLOCK-1))

if [ "$NEWSIZE" -le "$CURSIZE" ]; then
	echo "-> Partition $PART already has the maximum size. Not growing it.";
	exit 0;
fi

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

echo "-> Growing partition $PART to the outer end of the disk"

$SFDISK -N1 $DISK >/dev/null <<P1
,$NEWSIZE
y
P1

echo "-> Growing filesystem on $PART to partition size"
touch /etc/mtab
e2fsck -fy $PART
tune2fs -O ^has_journal $PART
resize2fs $PART
tune2fs -O has_journal $PART
tune2fs -i 0 -c 0 $PART

echo "-> Done"
