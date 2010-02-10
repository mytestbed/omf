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

for i in external/frisbee/frisbee external/frisbee/imagezip external/coderay-0.8.3 external/log4r-1.0.5 external/xmpp4r-0.4 omf-common ; do
	cd $i
	build
	cd $TOPDIR
done

cd omf-resctl
DEB=`bash -c "$BUILD"`
sudo alien -r -g ../$DEB
sudo rm -rf omf-resctl-5.3-1/etc/init.d
sudo mkdir -p omf-resctl-5.3-1/etc/rc.d/init.d
sudo cp ../omf-resctl/debian/init.d.fedora omf-resctl-5.3-1/etc/rc.d/init.d/omf-resctl-5.3
sudo chmod +x omf-resctl-5.3-1/etc/rc.d/init.d/omf-resctl-5.3
sudo sed -i 's/etc\/init.d/etc\/rc.d\/init.d/g' omf-resctl-5.3-1/omf-resctl-*.spec
sudo sed -i '/^Group: /a Requires: ruby wireless-tools wget pciutils imagezip libcoderay-ruby1.8 liblog4r-ruby1.8 libxmpp4r-ruby1.8 omf-common-5.3 omf-resctl-5.3' omf-resctl-5.3-1/omf-resctl-*.spec
sudo sed -i '/^(Converted /a %post\n/sbin/chkconfig --add omf-resctl-5.3\n/etc/init.d/omf-resctl-5.3 restart' omf-resctl-5.3-1/omf-resctl-*.spec
sudo rpmbuild -bb --buildroot `pwd`/omf-resctl-5.3-1 omf-resctl-5.3-1/omf-resctl-*.spec
sudo rm -rf omf-resctl-5.3-1
cd $TOPDIR

rm -f liblog4r-ruby-1*rpm libxmpp4r-ruby-1*rpm

ssh mytestbed.net rm -rf /var/www/packages/yum/base/8/i386/*
scp *.rpm mytestbed.net:/var/www/packages/yum/base/8/i386
ssh mytestbed.net createrepo /var/www/packages/yum/base/8/i386
