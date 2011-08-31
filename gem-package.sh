#!/bin/bash -x
GEMS=$PWD/gems/1.8
export rake=/usr/bin/rake
gem="gem install --no-rdoc --no-ri -i $GEMS"
mkdir -p $GEMS
echo "Downloading ruby gems required for OMF. This may take a while..."
egrep -v '^#' Gemfile | egrep -v '^[[:space:]]*$' | 
while read a; do
  $gem $a;
  until [ $? -eq 0 ]; do
    $gem $a;
  done
done

cd $GEMS
rm -rf doc gems specifications bin
