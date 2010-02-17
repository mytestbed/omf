#!/bin/bash

TOPDIR=`pwd`
BUILD='debuild -uc -us -b | grep "dpkg-deb: building package" | awk -F "../" "{print substr(\$2,0,length(\$2)-2)}"'

function build {
	DEB=`bash -c "$BUILD"`
	arr=$(echo $DEB | tr " " "\n")
	for x in $arr
	do
	    echo "Converting $x to rpm"
		sudo alien -r ../$x | awk -F ' ' '{print $1}' | xargs -I xx mv xx $TOPDIR
	done	
}

for i in external/frisbee/imagezip external/frisbee/frisbee external/coderay-0.8.3 external/log4r-1.0.5 external/xmpp4r-0.4 omf-common ; do
	cd $i
	build
	cd $TOPDIR
done

# OMF aggmgr
cd omf-aggmgr
DEB=`bash -c "$BUILD"`
echo "Converting $DEB to rpm"
RPM=`sudo alien -r -g ../$DEB | grep Directory | awk -F ' ' '{print $2}'`
if [ x$RPM == x ]; then
	echo "Error generating RPM package in `pwd`. Exiting."
	exit
fi
sudo rm -rf `pwd`/$RPM/etc/init.d
sudo mkdir -p $RPM/etc/rc.d/init.d
sudo cp ../omf-aggmgr/debian/init.d.fedora $RPM/etc/rc.d/init.d/omf-aggmgr-5.3
sudo chmod +x $RPM/etc/rc.d/init.d/omf-aggmgr-5.3
sudo sed -i 's/etc\/init.d/etc\/rc.d\/init.d/g' $RPM/$RPM*.spec
sudo sed -i '/^Group: /a Requires: ruby frisbee libmysql-ruby, libldap-ruby1.8 libsqlite3-ruby psmisc nmap netcat liblog4r-ruby1.8 libxmpp4r-ruby1.8 omf-common-5.3' $RPM/$RPM*.spec
sudo sed -i '/^(Converted /a %post\n/sbin/chkconfig --add omf-aggmgr-5.3\n/etc/init.d/omf-aggmgr-5.3 restart' $RPM/$RPM*.spec
sudo rpmbuild -bb --target noarch-none-linux --buildroot `pwd`/$RPM $RPM/omf-aggmgr-*.spec
sudo rm -rf `pwd`/$RPM
cd $TOPDIR

# OMF expctl
cd omf-expctl
DEB=`bash -c "$BUILD"`
echo "Converting $DEB to rpm"
RPM=`sudo alien -r -g ../$DEB | grep Directory | awk -F ' ' '{print $2}'`
if [ x$RPM == x ]; then
	echo "Error generating RPM package in `pwd`. Exiting."
	exit
fi
sudo sed -i '/^Group: /a Requires: ruby liblog4r-ruby1.8 libxmpp4r-ruby1.8 omf-common-5.3 libcoderay-ruby1.8 libmarkaby-ruby' $RPM/$RPM*.spec
sudo rpmbuild -bb --target noarch-none-linux --buildroot `pwd`/$RPM $RPM/omf-expctl-*.spec
sudo rm -rf `pwd`/$RPM
cd $TOPDIR

# OMF resctl
cd omf-resctl
DEB=`bash -c "$BUILD"`
echo "Converting $DEB to rpm"
RPM=`sudo alien -r -g ../$DEB | grep Directory | awk -F ' ' '{print $2}'`
if [ x$RPM == x ]; then
	echo "Error generating RPM package in `pwd`. Exiting."
	exit
fi
sudo rm -rf `pwd`/$RPM/etc/init.d
sudo mkdir -p $RPM/etc/rc.d/init.d
sudo cp ../omf-resctl/debian/init.d.fedora $RPM/etc/rc.d/init.d/omf-resctl-5.3
sudo chmod +x $RPM/etc/rc.d/init.d/omf-resctl-5.3
sudo sed -i 's/etc\/init.d/etc\/rc.d\/init.d/g' $RPM/$RPM*.spec
sudo sed -i '/^Group: /a Requires: ruby wireless-tools wget pciutils imagezip liblog4r-ruby1.8 libxmpp4r-ruby1.8 omf-common-5.3' $RPM/$RPM*.spec
sudo sed -i '/^(Converted /a %post\n/sbin/chkconfig --add omf-resctl-5.3\n/etc/init.d/omf-resctl-5.3 restart' $RPM/$RPM*.spec
sudo rpmbuild -bb --target noarch-none-linux --buildroot `pwd`/$RPM $RPM/omf-resctl-*.spec
sudo rm -rf `pwd`/$RPM
cd $TOPDIR

rm -f liblog4r-ruby-1*rpm libxmpp4r-ruby-1*rpm

ssh mytestbed.net rm -rf /var/www/packages/yum/base/8/i386/*
scp *.rpm mytestbed.net:/var/www/packages/yum/base/8/i386
ssh mytestbed.net createrepo /var/www/packages/yum/base/8/i386
