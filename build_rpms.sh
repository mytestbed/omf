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

# cd external/frisbee/frisbee
# build
# cd $TOPDIR
# 
# cd external/frisbee/imagezip
# build
# cd $TOPDIR
# 
# cd external/coderay-0.8.3
# build
# cd $TOPDIR
# 
# cd external/log4r-1.0.5 
# build
# cd $TOPDIR
# 
# cd external/xmpp4r-0.4
# build
# cd $TOPDIR
# 
# cd omf-common
# build
# cd $TOPDIR

cd omf-resctl
DEB=`bash -c "$BUILD"`
sudo alien -r -g ../$DEB
sudo rm -rf omf-resctl-5.3-1/etc/init.d
sudo mkdir -p omf-resctl-5.3-1/etc/rc.d/init.d
sudo cp ../omf-resctl/debian/init.d.fedora omf-resctl-5.3-1/etc/rc.d/init.d/omf-resctl-5.3
sudo sed -i 's/etc\/init.d/etc\/rc.d\/init.d/g' omf-resctl-5.3-1/omf-resctl-*.spec
sudo sed -i '/^Group: /a Requires: ruby wireless-tools wget pciutils imagezip libcoderay-ruby1.8 liblog4r-ruby1.8 libxmpp4r-ruby1.8 omf-common-5.3 omf-resctl-5.3' omf-resctl-5.3-1/omf-resctl-*.spec
sudo rpmbuild -bb --buildroot `pwd`/omf-resctl-5.3-1 omf-resctl-5.3-1/omf-resctl-*.spec
sudo rm -rf omf-resctl-5.3-1
cd $TOPDIR

rm -f liblog4r-ruby-1*rpm libxmpp4r-ruby-1*rpm

scp *.rpm mytestbed.net:/var/www/packages/yum/base/8/i386

ssh mytestbed.net createrepo /var/www/packages/yum/base/8/i386