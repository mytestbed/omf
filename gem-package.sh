#!/bin/bash
GEMS=$PWD/gems/1.8
gem="gem install --no-rdoc --no-ri -i $GEMS"
mkdir -p $GEMS
echo "Downloading ruby gems required for OMF. This may take a while..."
egrep -v '^#' Gemfile | egrep -v '^[[:space:]]*$' | while read a; do $gem $a; done
cd $GEMS
rm -rf doc gems specifications bin
