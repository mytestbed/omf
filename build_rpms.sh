#!/bin/bash

TOPDIR=`pwd`
#BUILD='debuild -uc -us -b | grep "dpkg-deb: building package" | awk -F "../" "{print substr(\$2,0,length(\$2)-1)}"'
BUILD='debuild -uc -us -b | grep "dpkg-deb: building package" | awk -F "../" "{print \$2}" | sed "s/\(.\+\)'\''./\1/"'

function build {
	DEB=`bash -c "$BUILD"`
	arr=$(echo $DEB | tr " " "\n")
	for x in $arr
	do
	    echo "Converting $x to rpm"
	    sudo alien -r ../$x | awk -F ' ' '{print $1}' | xargs -I xx mv xx $TOPDIR
	done	
}

for i in external/frisbee/imagezip external/frisbee/frisbee; do
	cd $i
	build
	cd $TOPDIR
done

# OMF common
cd omf-common
DEB=`bash -c "$BUILD"`
echo "Converting $DEB to rpm"
RPM=`sudo alien -r -g ../$DEB | grep Directory | awk -F ' ' '{print $2}'`
if [ x$RPM == x ]; then
	echo "Error generating RPM package in `pwd`. Exiting."
	exit
fi
sudo sed -i '/^(Converted /a %post\nln -s /usr/bin/ruby /usr/bin/ruby1.8\ncd /usr/share/omf-common-5.4/gems/1.8\n GEM_PATH=$PWD gem install --no-ri --no-rdoc -l -f cache/*.gem' $RPM/$RPM*.spec
sudo sed -i '/^Group: /a Requires: ruby(abi) = 1.8 ruby-devel rubygems rubygem-rake' $RPM/$RPM*.spec
sudo rpmbuild -bb --target noarch-none-linux --buildroot `pwd`/$RPM $RPM/omf-common-*.spec
sudo rm -rf `pwd`/$RPM
cd $TOPDIR

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
sudo cp ../omf-aggmgr/debian/init.d.fedora $RPM/etc/rc.d/init.d/omf-aggmgr-5.4
sudo chmod +x $RPM/etc/rc.d/init.d/omf-aggmgr-5.4
sudo sed -i 's/etc\/init.d/etc\/rc.d\/init.d/g' $RPM/$RPM*.spec
sudo sed -i '/^Group: /a Requires: ruby(abi) = 1.8 frisbee ruby-mysql, ruby-ldap ruby-sqlite3 psmisc nmap nc mysql-devel omf-common-5.4' $RPM/$RPM*.spec
sudo sed -i '/^(Converted /a %post\n/sbin/chkconfig --add omf-aggmgr-5.4\ncd /usr/share/omf-aggmgr-5.4/gems/1.8\n GEM_PATH=$PWD gem install --no-ri --no-rdoc -l -f cache/*.gem\n/etc/init.d/omf-aggmgr-5.4 restart' $RPM/$RPM*.spec
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
sudo sed -i '/^Group: /a Requires: omf-common-5.4' $RPM/$RPM*.spec
sudo sed -i '/conf_room_demo/d' $RPM/$RPM*.spec
sudo sed -i '/^(Converted /a %post\ncd /usr/share/omf-expctl-5.4/gems/1.8\n GEM_PATH=$PWD gem install --no-ri --no-rdoc -l -f cache/*.gem' $RPM/$RPM*.spec
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
sudo cp ../omf-resctl/debian/init.d.fedora $RPM/etc/rc.d/init.d/omf-resctl-5.4
sudo chmod +x $RPM/etc/rc.d/init.d/omf-resctl-5.4
sudo sed -i 's/etc\/init.d/etc\/rc.d\/init.d/g' $RPM/$RPM*.spec
sudo sed -i '/^Group: /a Requires: wireless-tools wget pciutils imagezip omf-common-5.4 util-linux-ng e2fsprogs' $RPM/$RPM*.spec
sudo sed -i '/^(Converted /a %post\n/sbin/chkconfig --add omf-resctl-5.4\n/etc/init.d/omf-resctl-5.4 restart' $RPM/$RPM*.spec
sudo rpmbuild -bb --target noarch-none-linux --buildroot `pwd`/$RPM $RPM/omf-resctl-*.spec
sudo rm -rf `pwd`/$RPM
cd $TOPDIR

read -p "Do you want to upload the RPMs to mytestbed.net (y/n)?"
if [ "$REPLY" == "y" ]; then
	scp omf-*.rpm mytestbed.net:/var/www/packages/rpm/5.4/f14/noarch/
	ssh mytestbed.net createrepo /var/www/packages/rpm/5.4/f14
	ssh mytestbed.net createrepo /var/www/packages/rpm/5.4/f8
fi
