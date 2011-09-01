#!/bin/bash 
GEMS=$PWD/gems/1.8
export rake=/usr/bin/rake
gem="gem install --no-rdoc --no-ri -i $GEMS"
mkdir -p $GEMS
echo "Downloading ruby gems required for OMF. This may take a while..."
# attempt to download each gem 3 times, exit on failure
failed=1
egrep -v '^#' Gemfile | egrep -v '^[[:space:]]*$' | 
while read a; do
  for i in {1..3}; do
    $gem $a;
    if [ $? -eq 0 ]; then break; fi
    if [ $i -eq 3 ]; then
      echo "Could not download required gem '$a'. Aborting."
      failed=0
      exit
    fi
    echo "Failed to download required gem '$a'. Retrying."
  done
done
if [ $failed -eq 0 ]; then exit 1; fi

cd $GEMS
rm -rf doc gems specifications bin
