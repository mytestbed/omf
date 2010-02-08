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

cd external/frisbee/frisbee
build
cd $TOPDIR

cd external/frisbee/imagezip
build
cd $TOPDIR

cd external/coderay-0.8.3
build
cd $TOPDIR

cd external/log4r-1.0.5 
build
cd $TOPDIR

cd external/xmpp4r-0.4
build
cd $TOPDIR

cd omf-common
build
cd $TOPDIR

cd omf-resctl
build
cd $TOPDIR

rm -f liblog4r-ruby-1*rpm libxmpp4r-ruby-1*rpm

scp *.rpm mytestbed.net:/var/www/packages/yum/base/8/i386

ssh mytestbed.net createrepo /var/www/packages/yum/base/8/i386