#
# Build the Orbit PXE kernel image and initramfs
#
NAME = orbit-pxe
VER = 2.0.4

DEB_REP=debian
KORG_URL = http://www.kernel.org/pub/linux/kernel/v
KERNEL_VERSION = 2
KERNEL_PATCHLEVEL = 6
KERNEL_SUBLEVEL = 25
KERNEL_EXTRAVERSION = .1
KERNEL_MAIN_VER=$(KERNEL_VERSION).$(KERNEL_PATCHLEVEL).$(KERNEL_SUBLEVEL)
KVER = $(KERNEL_MAIN_VER)$(KERNEL_EXTRAVERSION)
KERNEL_DIR = linux-$(KVER)
KERNEL_TAR = $(KERNEL_DIR).tar.gz
KERNEL_BASE_URL = $(KORG_URL)$(KERNEL_VERSION).$(KERNEL_PATCHLEVEL)
KERNEL_TAR_URL = $(KERNEL_BASE_URL)/$(KERNEL_TAR)
KERNEL_NAME = linux-$(NAME)-$(KVER)
BBOX_VERSION = 1.10.1
BBOX_DIR = busybox-$(BBOX_VERSION)
BBOX_TAR = busybox-$(BBOX_VERSION).tar.gz
BBOX_URL = http://busybox.net/downloads
BBOX_TAR_URL = $(BBOX_URL)/$(BBOX_TAR)
CURL_VERSION = 7.19.4
CURL_DIR = curl-$(CURL_VERSION)
CURL_TAR = curl-$(CURL_VERSION).tar.gz
CURL_URL = http://curl.haxx.se/download/
CURL_TAR_URL = $(CURL_URL)/$(CURL_TAR)

# --------  START OF SITE DEPENDENT VARIABLES ---------
#  In order to make this work for users outside of Winlab, the site
#  dependent variables are collected here. These allow you to redefine
#  a local package server, and local config files for kernel and busybox.
#
#  They may be definied in ENV VARS, or in an include file, if present.
#  The default values here are for winlab.
#
#  THEREFORE, in summary:
#  * If you are building for Winlab, edit the right hand side
#    of the following expressions.
#  * If you are not building for Winlab, edit ./site.mk.
#     (follow the example "nicta.mk")
#
-include ./site.mk
APT_HOST ?= http://apt
REPOSITORY ?= $(USER)@repository1
REPOSITORY_ROOT ?= /export/web/orbit/dists/testing/main
KEXEC_REP ?= debian/pool/main/k/kexec-tools
WINLAB_REP ?= winlab/binary
MAIN_REP ?= orbit/dists/testing/main/binary-i386
KERNEL_CONFIG_FILE ?= $(KERNEL_NAME).config
BBOX_CONFIG_FILE ?= $(BBOX_DIR).config
# --------  END OF SITE DEPENDENT VARIABLES ---------

INITRAMFS = initramfs-$(NAME)-$(VER)
INITRAMFSGZ = $(INITRAMFS).gz
INITRAMFS_LIST = $(INITRAMFS).list


GETMAC_DIR= getmac-1.0

FRISBEE_DEB=frisbee_1.0.3-1_i386.deb
FRISBEE_DEB_URL = $(APT_HOST)/$(WINLAB_REP)/$(FRISBEE_DEB)
IMAGEZIP_DEB=imagezip_1.0.0-1_i386.deb
IMAGEZIP_DEB_URL = $(APT_HOST)/$(WINLAB_REP)/$(IMAGEZIP_DEB)

# Set here for nodeagent4, or set using 'make NEW_NODEAGENT=1'
NEW_NODEAGENT=1
ifeq ($(NEW_NODEAGENT), 1)
  #NODEAGENT_DEB=nodeagent4_4.3.0_all.deb
  NODEAGENT_DEB=$(shell sudo apt-cache show nodeagent4 |  \
	grep -m 1  "Filename:" | \
	cut -d" " -f 2 | sed -e 's|\(.*\)/\(.*deb\)|\2|g')
  NODEAGENT_ETC=/etc/nodeagent4
else
  NODEAGENT_DEB=nodeagent_3.4.3_1_all.deb
  #NODEAGENT_DEB=nodeagent_4.1.2_all.deb
  NODEAGENT_ETC=/etc/nodeagent
endif
NODEAGENT_DEB_URL= $(APT_HOST)/$(MAIN_REP)/$(NODEAGENT_DEB)
NODEAGENT_CONF=nodeagent.yaml

# This will go away with buildroot
KEXEC_PATH=$(shell sudo apt-cache show kexec-tools | grep -m 1  "Filename:" | \
	cut -d" " -f 2 | sed -e 's|\(.*\)/\(.*deb\)|\1|g')
KEXEC_DEB=$(shell sudo apt-cache show kexec-tools | grep -m 1  "Filename:" | \
	cut -d" " -f 2 | sed -e 's|\(.*\)/\(.*deb\)|\2|g')
KEXEC_DEB_URL = $(APT_HOST)/$(DEB_REP)/$(KEXEC_PATH)/$(KEXEC_DEB)

# nodeagent looks for this, but not necessary, nuke
TZDATA_PATH=$(shell sudo apt-cache show tzdata | grep -m 1 "Filename:" | \
	cut -d" " -f 2 | sed -e 's|\(.*\)/\(.*deb\)|\1|g')
TZDATA_DEB=$(shell sudo apt-cache show tzdata | grep -m 1  "Filename:" | \
	cut -d" " -f 2 | sed -e 's|\(.*\)/\(.*deb\)|\2|g')
TZDATA_DEB_URL=$(APT_HOST)/$(DEB_REP)/$(TZDATA_PATH)/$(TZDATA_DEB)
TZDIR=/usr/share/zoneinfo/US/
TZFILE=$(TZDIR)/Eastern

SYSLINUX_PATH=$(shell sudo apt-cache show syslinux | grep -m 1 "Filename:" | \
	cut -d" " -f 2 | sed -e 's|\(.*\)/\(.*deb\)|\1|g')
SYSLINUX_DEB=$(shell sudo apt-cache show syslinux | grep -m 1  "Filename:" | \
	cut -d" " -f 2 | sed -e 's|\(.*\)/\(.*deb\)|\2|g')
SYSLINUX_DEB_URL=$(APT_HOST)/$(DEB_REP)/$(SYSLINUX_PATH)/$(SYSLINUX_DEB)
PXE_PATH=/usr/lib/syslinux/
PXE_SRC=pxelinux.0
PXE_DST=pxelinux.bin

TFTP_DIR = /tftpboot
CFG_DIR = $(TFTP_DIR)/pxelinux.cfg

# Where we get our build config files from
CONFIG = config
# Where the kernel and initramfs end up
BUILD = build
# What we'll build our initramfs rootfs from
ROOTFS = rootfs
# Where the tars are dl'ed and extracted
SOURCE = src
# Dump temp data
TEMP = tmp

# Add new libs as necessary, and move to uClibc ASAP, this means killing 
# all ruby slowly
LIB =	/lib/ld-linux.so.2 /lib/libc.so.6 /lib/libm.so.6 /lib/libpthread.so.0 
LIB +=	/lib/libdl.so.2 /lib/libcrypt.so.1 
LIB +=	/lib/libnss_dns.so.2 /lib/libresolv.so.2
# Currently nodeagent requires lspci, which requires libpci. Remove this 
# if not needed.
#LIB += /usr/lib/libpci.so.2 /usr/lib/libz.so.1
LIB += /usr/lib/libz.so.1
# as well as lsusb
LIB +=  /lib/libusb-0.1.so.4
# for curl
LIB +=  /lib/librt.so.1
UCLIBC = /lib/ld-uClibc.so.0 /lib/libc.so.0 /lib/libm.so.0

#all: apt-get-update kernel initramfs
all: kernel initramfs

apt-get-update:
	sudo apt-get update

dirs:
	install -d $(BUILD) $(ROOTFS) $(SOURCE) $(TEMP)

bbox: 	get_bbox
	if [ ! -r $(SOURCE)/$(BBOX_DIR) ] ; then \
	  tar -xzf $(SOURCE)/$(BBOX_TAR) -C $(SOURCE); \
	fi
	cp $(CONFIG)/$(BBOX_CONFIG_FILE) $(SOURCE)/$(BBOX_DIR)/.config
	sed 's|CONFIG_PREFIX=.*|CONFIG_PREFIX=\"../../$(ROOTFS)/\"|'  \
	  $(CONFIG)/$(BBOX_CONFIG_FILE) > $(SOURCE)/$(BBOX_DIR)/.config
	$(MAKE) -C $(SOURCE)/$(BBOX_DIR) install

curl: 	get_curl
	if [ ! -r $(SOURCE)/$(CURL_DIR) ] ; then \
	  tar -xzf $(SOURCE)/$(CURL_TAR) -C $(SOURCE); \
	fi
	(cd $(SOURCE)/$(CURL_DIR); ./configure --without-ssl)
	mkdir -p $(SOURCE)/$(CURL_DIR)/install
	$(MAKE) -C $(SOURCE)/$(CURL_DIR) install DESTDIR=`pwd`/$(SOURCE)/$(CURL_DIR)/install
	install -d $(ROOTFS)/usr/bin
	install -d $(ROOTFS)/usr/lib
	install -m 755 `pwd`/$(SOURCE)/$(CURL_DIR)/install/usr/local/bin/curl $(ROOTFS)/usr/bin/
	cp -d `pwd`/$(SOURCE)/$(CURL_DIR)/install/usr/local/lib/lib* $(ROOTFS)/usr/lib

frisbee: get_frisbee
	dpkg -x $(SOURCE)/$(FRISBEE_DEB) $(TEMP)
	dpkg -x $(SOURCE)/$(IMAGEZIP_DEB) $(TEMP)
	install -d $(ROOTFS)/usr/bin/
	install -d $(ROOTFS)/usr/sbin/
	install -m 755 $(TEMP)/usr/sbin/frisbee $(ROOTFS)/usr/sbin/
	install -m 755 $(TEMP)/usr/bin/imagezip $(ROOTFS)/usr/bin/

nodeagent: get_nodeagent get_tzdata
	dpkg -x $(SOURCE)/$(NODEAGENT_DEB) $(ROOTFS)
	install -m 644 $(CONFIG)/$(NODEAGENT_CONF)  $(ROOTFS)/$(NODEAGENT_ETC)/
	if [ "$(TZDATA_DEB)" != "" ] ; then \
	  dpkg -x $(SOURCE)/$(TZDATA_DEB) $(TEMP);\
		install -d $(ROOTFS)/$(TZDIR);\
		install $(TEMP)/$(TZFILE) $(ROOTFS)/$(TZFILE);\
	fi

syslinux: get_syslinux
	dpkg -x $(SOURCE)/$(SYSLINUX_DEB) $(TEMP)
	install -m 755 $(TEMP)/$(PXE_PATH)/$(PXE_SRC)  $(BUILD)/$(PXE_DST)

getmac:
	make -C $(GETMAC_DIR)/ install DESTDIR=$(CURDIR)/$(ROOTFS)/

enroll:
	install --mode=770 $(CONFIG)/enroll $(ROOTFS)/dev/

kexec: get_kexec
	dpkg -x $(SOURCE)/$(KEXEC_DEB) $(ROOTFS)

filesystem: dirs
	install -d $(ROOTFS)/tmp
	install -d $(ROOTFS)/var
	install -d $(ROOTFS)/var/log
	install -d $(ROOTFS)/log
	install -d $(ROOTFS)/var/run
	install -d $(ROOTFS)/var/lib
	install -d $(ROOTFS)/lib
	install -d $(ROOTFS)/sbin
	install $(LIB) $(ROOTFS)/lib
	install -d $(ROOTFS)/etc
	install -d $(ROOTFS)/etc/init.d
	install -d $(ROOTFS)/proc
	install -d $(ROOTFS)/dev
	-sudo mknod -m 666 $(ROOTFS)/dev/urandom c 1 9
	-sudo mknod -m 660 $(ROOTFS)/dev/console c 5 1
	-sudo mknod -m 666 $(ROOTFS)/dev/null c 1 3
	-sudo mknod -m 666 $(ROOTFS)/dev/tty0 c 4 0
	-sudo mknod -m 666 $(ROOTFS)/dev/tty1 c 4 1
	-sudo mknod -m 666 $(ROOTFS)/dev/tty2 c 4 2
	-sudo mknod -m 666 $(ROOTFS)/dev/tty3 c 4 3
	-sudo mknod -m 666 $(ROOTFS)/dev/tty4 c 4 4
	-sudo mknod -m 600 $(ROOTFS)/dev/ttyS0 c 4 64
	-sudo mknod -m 600 $(ROOTFS)/dev/ttyp0 c 3 0
	-sudo mknod -m 620 $(ROOTFS)/dev/ptmx c 5 2
	-sudo mknod -m 660 $(ROOTFS)/dev/hda b 3 0
	-sudo mknod -m 660 $(ROOTFS)/dev/hda1 b 3 1
	-sudo mknod -m 660 $(ROOTFS)/dev/hda2 b 3 2
	-sudo mknod -m 660 $(ROOTFS)/dev/hda3 b 3 3
	-sudo mknod -m 660 $(ROOTFS)/dev/sda b 8 0
	-sudo mknod -m 660 $(ROOTFS)/dev/sda1 b 8 1
	-sudo mknod -m 660 $(ROOTFS)/dev/sda2 b 8 2
	-sudo mknod -m 660 $(ROOTFS)/dev/sda3 b 8 3
	-sudo mknod -m 660 $(ROOTFS)/dev/sda4 b 8 4
	-sudo mknod -m 600 $(ROOTFS)/dev/initctl p
	sudo chown `id -u`:`id -g` $(ROOTFS)/dev/*
	cd $(ROOTFS) && ln -sf sbin/init init
	install -m 755 $(CONFIG)/rcS $(ROOTFS)/etc/init.d/
	install -m 755 $(CONFIG)/udhcp* $(ROOTFS)/etc/
	install -m 644 $(CONFIG)/passwd $(ROOTFS)/etc/
	install -m 644 $(CONFIG)/group $(ROOTFS)/etc/
	install -m 644 $(CONFIG)/services $(ROOTFS)/etc/
	install -m 644 $(CONFIG)/inittab $(ROOTFS)/etc/
	# ubuntu/debian compatibility: use 'which' to locate lspci:
	install -m 755 `which lspci` $(ROOTFS)/bin/lspci
	install -m 755 /usr/sbin/lsusb $(ROOTFS)/bin/lsusb
	# ubuntu or debian variation in location of example files:
	if [ -f /var/lib/misc/usb.ids ]; then \
    install -d $(ROOTFS)/var/lib/misc; \
   	install -m 755 /var/lib/misc/usb.ids $(ROOTFS)/var/lib/misc; \
	elif [ -f /var/lib/usbutils/usb.ids ]; then \
    install -d $(ROOTFS)/var/lib/usbutils; \
	 	install -m 755 /var/lib/usbutils/usb.ids $(ROOTFS)/var/lib/usbutils; \
  fi
	install -m 755 /sbin/shutdown $(ROOTFS)/sbin/
	echo "US/Eastern" > $(ROOTFS)/etc/timezone
	echo "pxe:$(VER)" > $(ROOTFS)/.orbit_image

kernel: dirs get_kernel
	if [ ! -r $(BUILD)/$(KERNEL_NAME) ] ; then \
	  cp $(CONFIG)/$(KERNEL_CONFIG_FILE) $(SOURCE)/$(KERNEL_DIR)/.config ;\
	  $(MAKE) -C $(SOURCE)/$(KERNEL_DIR) -j8 bzImage; \
          cp $(SOURCE)/$(KERNEL_DIR)/arch/i386/boot/bzImage \
	    $(BUILD)/$(KERNEL_NAME) ; \
	fi

# Note: current kernel expects init on initramfs on /init, not /sbin/init
initramfs: dirs bbox curl filesystem frisbee nodeagent enroll syslinux kexec \
	getmac get_init_cpio
	rm -f $(BUILD)/$(INITRAMFS) $(BUILD)/$(INITRAMFSGZ)
	rm -rf $(ROOTFS)/usr/share/doc/ $(ROOTFS)/usr/share/man/
	/bin/bash $(SOURCE)/$(KERNEL_DIR)/scripts/gen_initramfs_list.sh \
		-u `id -u` -g `id -g` $(ROOTFS) > $(TEMP)/$(INITRAMFS_LIST)
	$(SOURCE)/$(KERNEL_DIR)/usr/gen_init_cpio \
		$(TEMP)/$(INITRAMFS_LIST) > $(BUILD)/$(INITRAMFS)
	gzip -f -9 $(BUILD)/$(INITRAMFS)

get_init_cpio: get_kernel
	if [ ! -f $(SOURCE)/$(KERNEL_DIR)/usr/gen_init_cpio ] ; then \
	  cd $(SOURCE)/$(KERNEL_DIR)/usr/ && make gen_init_cpio ;\
	fi

get_kernel:
	if [ ! -d $(SOURCE)/$(KERNEL_DIR) ] ; then \
	  if [ -f /usr/src/$(KERNEL_TAR) ] ; then \
	    tar -xzf /usr/src/$(KERNEL_TAR) -C $(SOURCE); \
	  else  \
	    wget -P $(SOURCE) $(KERNEL_TAR_URL); \
	    tar -xzf $(SOURCE)/$(KERNEL_TAR) -C $(SOURCE); \
	  fi;\
	fi

get_bbox: 
	if [ ! -r $(SOURCE)/$(BBOX_TAR) ] ; then \
	wget -P $(SOURCE) $(BBOX_TAR_URL); \
	fi

get_curl:
	if [ ! -r $(SOURCE)/$(CURL_TAR) ] ; then \
	wget -P $(SOURCE) $(CURL_TAR_URL); \
	fi

get_frisbee:
	if [ ! -r $(SOURCE)/$(FRISBEE_DEB) ] ; then \
	wget -P $(SOURCE) $(FRISBEE_DEB_URL); \
	wget -P $(SOURCE) $(IMAGEZIP_DEB_URL); \
	fi

get_nodeagent:
	if [ ! -r $(SOURCE)/$(NODEAGENT_DEB) ] ; then \
	wget -P $(SOURCE) $(NODEAGENT_DEB_URL); \
	fi

get_tzdata:
	if [ ! -r $(SOURCE)/$(TZDATA_DEB) ] ; then \
	wget -P $(SOURCE) $(TZDATA_DEB_URL); \
	fi

get_syslinux:
	if [ ! -r $(SOURCE)/$(SYSLINUX_DEB) ] ; then \
	wget -P $(SOURCE) $(SYSLINUX_DEB_URL); \
	fi	

get_kexec:
	if [ ! -r $(SOURCE)/$(KEXEC_DEB) ] ; then \
	wget -P $(SOURCE) $(KEXEC_DEB_URL); \
	fi

install: kernel initramfs
	install -d $(DESTDIR)/$(TFTP_DIR)
	install -m666 $(BUILD)/$(KERNEL_NAME) $(DESTDIR)/$(TFTP_DIR)
	install -m666 $(BUILD)/$(INITRAMFSGZ) $(DESTDIR)/$(TFTP_DIR)
	install -m755 $(BUILD)/$(INITRAMFSGZ) $(DESTDIR)/$(TFTP_DIR)
	install -m755 $(BUILD)/$(PXE_DST) $(DESTDIR)/$(TFTP_DIR)
	install -d $(DESTDIR)/$(CFG_DIR)
	sed -e s/@KERNEL_VER@/$(KVER)/ $(CONFIG)/default.orbit | \
	  sed -e s/@VER@/$(VER)/ > $(DESTDIR)/$(CFG_DIR)/orbit-$(VER)
	install -m755 $(CONFIG)/makeLink $(DESTDIR)/$(CFG_DIR)

deb:
	debuild

apt-install: deb
	scp ../*.deb $(REPOSITORY):$(REPOSITORY_ROOT)/binary-i386
	scp ../*.gz $(REPOSITORY):$(REPOSITORY_ROOT)/source
	scp ../*.dsc $(REPOSITORY):$(REPOSITORY_ROOT)/source
	ssh $(REPOSITORY) sudo $(REPOSITORY_ROOT)/rebuild.sh

clean:
	rm -rf $(BUILD) $(ROOTFS)
	if [ -d $(SOURCE)/$(KERNEL_DIR) ] ; then \
	  $(MAKE) -C $(SOURCE)/$(KERNEL_DIR) clean ; \
	fi
	if [ -d $(SOURCE)/$(BBOX_DIR) ] ; then \
	  $(MAKE) -C $(SOURCE)/$(BBOX_DIR) clean ; \
	fi
	if [ -d $(SOURCE)/$(CURL_DIR) ] ; then \
	  $(MAKE) -C $(SOURCE)/$(CURL_DIR) clean ; \
	fi
	$(MAKE) -C $(GETMAC_DIR)/ clean

mrproper:
	rm -rf $(BUILD) $(ROOTFS) $(SOURCE) $(TEMP)

.PHONY: all apt-get-update dirs bbox curl frisbee nodeagent syslinux getmac enroll \
	kexec filesystem kernel initramfs get_init_cpio get_kernelget_bbox \
	get_frisbee get_nodeagent get_tzdata get_syslinux get_kexec install \
	deb apt-install clean mrproper
