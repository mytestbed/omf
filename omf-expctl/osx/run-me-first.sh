#!/bin/sh

# Please this script first before opening the OSX Package Maker project
# which you will use to build another package.
#
# The purpose of this script is to get the revision number from git and
# set it inside the post install script which will be run on the target
# machine where the package will be installed. This is required for now
# as the OSX Package Maker does not have any "pre-build script to run"
# option (it does have pre and post install scripts, but this is not
# what we need here, as git may not be installed on the target machine)

if [ `which git` ]; then 
  V=`git rev-parse --short HEAD`
else
  V="testing"
fi
sed "3s/.*/REVISION=\"$V\"/" post-install.sh > pi
mv -f pi post-install.sh
chmod 755 post-install.sh
