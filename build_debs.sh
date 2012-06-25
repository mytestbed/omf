#!/bin/bash

packages="omf-aggmgr omf-common omf-expctl omf-oml omf-resctl omf-web"

rm *.deb *.changes *.upload *.build

for deb in $packages
do
  echo "Building $deb"
  cd $deb
  debuild -uc -us -b
  cd ..
done

