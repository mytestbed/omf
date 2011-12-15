#!/bin/bash 
GEMS=$PWD/gems/1.8
export rake=/usr/bin/rake
gem="gem install --no-rdoc --no-ri -i $GEMS"
mkdir -p $GEMS
echo "Downloading ruby gems required for OMF. This may take a while..."

# read Gemfile
gem_array=()
i=0
while read line; do
  # ignore comments
  if [[ $line == \#* ]]; then continue; fi
  # ignore empty lines
  if [[ ${line// /} == "" ]]; then continue; fi
  gem_array[$i]=$line
  let i++
done < Gemfile

# attempt to download each gem 3 times, exit on failure
for g in "${gem_array[@]}"; do
  for i in {1..3}; do
    $gem $g;
    if [ $? -eq 0 ]; then break; fi
    if [ $i -eq 3 ]; then
      echo "Could not download required gem '$g'. Aborting."
      exit 1
    fi
    echo "Failed to download required gem '$g'. Retrying."
  done
done

cd $GEMS
rm -rf doc gems specifications bin
