#!/bin/sh
VERSION="5.3"
INDIR="/tmp/omf-install-tmp/"

# Ruby of EC
mv $INDIR/omf-expctl/ruby /usr/share/omf-expctl-$VERSION
chown -R root /usr/share/omf-expctl-$VERSION
chgrp -R admin /usr/share/omf-expctl-$VERSION

# Repository of EC
mv $INDIR/omf-expctl/share/repository /usr/share/omf-expctl-$VERSION
chown -R root /usr/share/omf-expctl-$VERSION/repository
chgrp -R admin /usr/share/omf-expctl-$VERSION/repository

# etc of EC
mv $INDIR/omf-expctl/etc/omf-expctl /etc/omf-expctl-$VERSION
chown -R root /etc/omf-expctl-$VERSION
chgrp -R admin /etc/omf-expctl-$VERSION

# bin of EC
cp $INDIR/omf-expctl/bin/omf /usr/bin/omf-$VERSION
cp $INDIR/omf-expctl/bin/omf_exec /usr/bin/omf_exec-$VERSION
cp $INDIR/omf-expctl/bin/omf_load /usr/bin/omf_load-$VERSION
cp $INDIR/omf-expctl/bin/omf_save /usr/bin/omf_save-$VERSION
cp $INDIR/omf-expctl/bin/omf_stat /usr/bin/omf_stat-$VERSION
cp $INDIR/omf-expctl/bin/omf_tell /usr/bin/omf_tell-$VERSION
if [ ! -e "/usr/bin/ruby1.8" ]
then
  ln -s /usr/bin/ruby /usr/bin/ruby1.8
fi

# Common
mv $INDIR/omf-common/ruby /usr/share/omf-common-$VERSION
chown -R root /usr/share/omf-common-$VERSION
chgrp -R admin /usr/share/omf-common-$VERSION

# Externals
chown -R root $INDIR/external/coderay-0.8.3
chgrp -R admin $INDIR/external/coderay-0.8.3
mv $INDIR/external/coderay-0.8.3/ruby/* /usr/lib/ruby/1.8/
chown -R root $INDIR/external/log4r-1.0.5
chgrp -R admin $INDIR/external/log4r-1.0.5
mv $INDIR/external/log4r-1.0.5/src/* /usr/lib/ruby/1.8/
chown -R root $INDIR/external/xmpp4r-0.4
chgrp -R admin $INDIR/external/xmpp4r-0.4
mv $INDIR/external/xmpp4r-0.4/lib/* /usr/lib/ruby/1.8/

# Clean up
rm -rf $INDIR





