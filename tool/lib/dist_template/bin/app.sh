#!/bin/sh
PDIR=@INSTALL_DIR@
APP=@APP_SCRIPT@

export PATH=$PDIR/sbin:$PATH
export LD_LIBRARY_PATH=$PDIR/sbin:LD_LIBRARY_PATH
export RUBYLIB=$PDIR/lib
export RUBYHOME=$PDIR

exec $PDIR/sbin/ruby $PDIR/app/$APP $*
