#!/usr/bin/ruby

# (c) 2012 National ICT Australia
# christoph.dwertmann@nicta.com.au

usage = "-> Usage: #{$0} <disk> <target size in GB | 0 | free space percentage>
e.g. #{$0} /dev/sda 20
e.g. #{$0} /dev/sda 10%
If the second parameter is a positive number, resize the first partition to that size in GB.
If the second parameter is 0, grow the first partition to maximum (disk) size
If the second parameter is a percentage, the first partition will be resized with the given percentage (approximately) of free space left
WARNING: Only the first partition will be resized. All other partitions will be destroyed!"

abort(usage) if ARGV.length != 2

disk = ARGV[0]
part = "#{disk}1"
size = ARGV[1]

abort "-> Could not find device #{disk}." if !system("fdisk -l | grep #{disk}")
abort "-> One or more partitions of #{disk} are mounted. Umount them and try again." if system("mount | grep #{disk}")

puts "-> Checking disk and partition sizes"

# re-read partition table in case it has been changed by frisbee
`sfdisk -R #{disk}`

targetsize=nil
cursize=`sfdisk #{part} -uB -s`.to_i
totalsize=`sfdisk #{disk} -uB -s`.to_i
firstblock=`sfdisk #{disk} -uB -l | grep #{part} | awk '{ sub(/\\+/,"");sub(/\\-/,"");print $2 }'`.to_i
maxsize=totalsize-firstblock-1

puts "-> Checking for disk usage on #{part}"
`mkdir -p /mnt/resize; mount #{part} /mnt/resize`
usage=`df | grep #{part} |  awk '{ printf "%d", $3 }'`.to_i
`sync; umount /mnt/resize`

case size
when /^\d+%$/
  p = size.to_i
  abort "Invalid free space percentage: #{size}" if p < 1 || p > 99
  targetsize=usage+usage*p/(100-p)
  # catering for the difference 
  targetsize=(targetsize*1.08).to_i
  # %10 safety margin, since df reports a smaller value for the disk size than sfdisk
  abort "Cannot resize the partition on #{disk} to include #{size} free disk space. Your disk is either too full and/or too small." if targetsize > maxsize*0.9
when "0"
  targetsize=maxsize
when /^\d+$/
  targetsize=size.to_i*1024*1024
  abort "Cannot resize the partition on #{disk} to #{size}GB. Your disk is too small." if targetsize > maxsize
  abort "Cannot resize the partition on #{disk} to #{size}GB. Your disk is too full." if targetsize < usage
else
  abort "Invalid target size: #{size}"
end

puts "-> Target size is #{targetsize} 1k blocks"

puts "-> Preparing filesystem for resizing"
`touch /etc/mtab
e2fsck -fy #{part}
tune2fs -O ^has_journal #{part}`

if targetsize < cursize
  # we need to shrink before we grow
  puts "-> Shrinking filesystem on #{part} to minimal size"
  `resize2fs -M #{part} 2>&1`
end

puts "-> Removing partition table entries 2, 3 and 4"

SFDISK="sfdisk -q -L -uB -f --no-reread"

`#{SFDISK} -N2 #{disk} >/dev/null <<P2
0,0,0
P2`

`#{SFDISK} -N3 #{disk} >/dev/null <<P3
0,0,0
P3`

`#{SFDISK} -N4 #{disk} >/dev/null <<P4
0,0,0
P4`

puts "-> Growing partition #{part}"

`#{SFDISK} -N1 #{disk} >/dev/null <<P1
,#{targetsize}
y
P1`

# re-read partition table
`sfdisk -f --no-reread -R #{disk}`

puts "-> Growing filesystem on #{part} to partition size"

`resize2fs #{part}
tune2fs -O has_journal #{part}
tune2fs -i 0 -c 0 #{part}`

puts "-> Done"

