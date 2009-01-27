#!/bin/bash
# -----------------------------------------------------
# This is an EXAMPLE only. 
# It is the script used to rebuild the package indexes,
#  as used at National ICT Australia orbit labs.
# -----------------------------------------------------
cd /var/www
dpkg-scanpackages dists/testing/main /dev/null | gzip > dists/testing/main/binary-i386/Packages.gz
dpkg-scanpackages dists/testing/winlab /dev/null | gzip > dists/testing/winlab/binary-i386/Packages.gz
dpkg-scanpackages dists/unstable/main /dev/null | gzip > dists/unstable/main/binary-i386/Packages.gz
dpkg-scanpackages dists/unstable/winlab /dev/null | gzip > dists/unstable/winlab/binary-i386/Packages.gz
chmod g+w dists/testing/main/binary-i386/Packages.gz dists/testing/winlab/binary-i386/Packages.gz dists/unstable/main/binary-i386/Packages.gz dists/unstable/winlab/binary-i386/Packages.gz
chgrp users dists/testing/main/binary-i386/Packages.gz dists/testing/winlab/binary-i386/Packages.gz dists/unstable/main/binary-i386/Packages.gz dists/unstable/winlab/binary-i386/Packages.gz
