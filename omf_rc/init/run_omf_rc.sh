#!/bin/bash

# Startup wrapper for the OMF6 RC
# detects system-wide RVM installations & Ruby from distro packages
# and runs OMF6 RC

# system-wide RVM must be installed using
# '\curl -L https://get.rvm.io | sudo bash -s stable'

die() { echo "ERROR: $@" 1>&2 ; exit 1; }

RUBY_VER="ruby-1.9.3-p286"
RUBY_BIN_SUFFIX=""

function compare_version {
  echo $1
  if [[ $1 == $2 ]]; then
    return 0
  fi
  local IFS=.
  local i ver1=($1) ver2=($2)
  # fill empty fields in ver1 with zeros
  for ((i=${#ver1[@]}; i<${#ver2[@]}; i++)); do
    ver1[i]=0
  done
  for ((i=0; i<${#ver1[@]}; i++)); do
    if [[ -z ${ver2[i]} ]]; then
      # fill empty fields in ver2 with zeros
      ver2[i]=0
    fi
    if ((10#${ver1[i]} > 10#${ver2[i]})); then
      return 1
    fi
    if ((10#${ver1[i]} < 10#${ver2[i]})); then
      return 2
    fi
  done
  return 0
}

if [ `id -u` != "0" ]; then
  die "This script is intended to be run as 'root'"
fi

if [ -e /etc/profile.d/rvm.sh ]; then
  # use RVM if installed
  echo "System-wide RVM installation detected"
  source /etc/profile.d/rvm.sh
  if [[ $? != 0 ]] ; then
    die "Failed to initialize RVM environment"
  fi
  rvm use $RUBY_VER@omf > /dev/null
  if [[ $? != 0 ]] ; then
    die "$RUBY_VER with gemset 'omf' is not installed in your RVM"
  fi
  ruby -v | grep 1.9.3  > /dev/null
  if [[ $? != 0 ]] ; then
    die "Could not run Ruby 1.9.3"
  fi
  gem list | grep omf_rc  > /dev/null
  if [[ $? != 0 ]] ; then
    die "The omf_rc gem is not installed in the 'omf' gemset"
  fi
else
  # check for distro ruby when no RVM was found
  echo "No system-wide RVM installation detected"
  compare_version `ruby -v | awk -F" p" '{ print $2; }'` 1.9.3
  if [[ $? == 2 ]]; then
    ruby1.9.3 -v | grep 1.9.3  > /dev/null
    if [[ $? != 0 ]] ; then
      die "Could not run system Ruby 1.9.3. No suitable Ruby installation found."
    fi
    RUBY_BIN_SUFFIX="1.9.3"
  fi
  echo "Ruby 1.9.3 + found"
  gem$RUBY_BIN_SUFFIX list | grep omf_rc  > /dev/null
  if [[ $? != 0 ]] ; then
    die "The omf_rc gem is not installed"
  fi
fi

RC=`which omf_rc`
if [[ $? != 0 ]] ; then
  die "could not find omf_rc executable"
fi

echo "Running OMF6 RC"
exec /usr/bin/env ruby$RUBY_BIN_SUFFIX $RC -c /etc/omf_rc/config.yml $@
