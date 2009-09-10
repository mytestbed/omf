#
# Build the Orbit PXE kernel image and initramfs
#
NAME = omf-pxe
VER = 2.0.6

DEB_REP=debian
KORG_URL = http://www.kernel.org/pub/linux/kernel/v
KERNEL_VERSION = 2
KERNEL_PATCHLEVEL = 6
KERNEL_SUBLEVEL = 29
KERNEL_EXTRAVERSION = .2
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
WINLAB_REP ?= winlab/binary
MAIN_REP ?= orbit/dists/testing/main/binary-i386
KERNEL_CONFIG_FILE ?= $(KERNEL_NAME).config
BBOX_CONFIG_FILE ?= $(BBOX_DIR).config
# --------  END OF SITE DEPENDENT VARIABLES ---------

INITRAMFS = initramfs-$(NAME)-$(VER)
INITRAMFSGZ = $(INITRAMFS).gz
INITRAMFS_LIST = $(INITRAMFS).list


GETMAC_DIR= getmac-1.0

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
LIB += /usr/lib/libpci.so.3
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
	if [ ! -r $(ROOTFS)/usr/bin/curl ] ; then \
       	  (cd $(SOURCE)/$(CURL_DIR); ./configure --without-ssl); \
	  mkdir -p $(SOURCE)/$(CURL_DIR)/install; \
	  $(MAKE) -C $(SOURCE)/$(CURL_DIR) install DESTDIR=`pwd`/$(SOURCE)/$(CURL_DIR)/install; \
	  install -d $(ROOTFS)/usr/bin; \
	  install -d $(ROOTFS)/usr/lib; \
	  install -m 755 `pwd`/$(SOURCE)/$(CURL_DIR)/install/usr/local/bin/curl $(ROOTFS)/usr/bin/; \
	  cp -d `pwd`/$(SOURCE)/$(CURL_DIR)/install/usr/local/lib/lib* $(ROOTFS)/usr/lib; \
	fi

omf:
	sudo apt-get clean; sudo apt-get update
	apt-get -d --reinstall --force-yes -y --print-uris install omf-common omf-resctl libxmpp4r-ruby libxmpp4r-ruby1.8 liblog4r-ruby liblog4r-ruby1.8 ruby1.8 libruby1.8 bash libncurses5 frisbee imagezip zlib1g libssl0.9.8 libgcc1 syslinux kexec-tools | grep http | awk '{print $$1}' | tr -d "'" > omf-packages
	mkdir -p $(SOURCE)/omf; cd $(SOURCE)/omf; rm *.deb; wget -N -i ../../omf-packages
	for file in `ls $(SOURCE)/omf/*.deb`; do dpkg -x $$file $(ROOTFS); done

syslinux: omf
	dpkg -x $(SOURCE)/omf/syslinux* $(TEMP)
	install -m 755 $(TEMP)/$(PXE_PATH)/$(PXE_SRC)  $(BUILD)/$(PXE_DST)

getmac:
	make -C $(GETMAC_DIR)/ install DESTDIR=$(CURDIR)/$(ROOTFS)/

enroll:
	install --mode=770 $(CONFIG)/enroll $(ROOTFS)/dev/

kexec: omf
	dpkg -x $(SOURCE)/omf/kexec* $(ROOTFS)

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
	install -m 755 $(CONFIG)/rcS.actual $(ROOTFS)/etc/init.d/	
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
	echo "pxe-$(VER)" > $(ROOTFS)/.omf_imageid

kernel: dirs get_kernel
	if [ ! -r $(BUILD)/$(KERNEL_NAME) ] ; then \
	  cp $(CONFIG)/$(KERNEL_CONFIG_FILE) $(SOURCE)/$(KERNEL_DIR)/.config ;\
	  $(MAKE) -C $(SOURCE)/$(KERNEL_DIR) -j8 bzImage; \
          cp $(SOURCE)/$(KERNEL_DIR)/arch/i386/boot/bzImage \
	    $(BUILD)/$(KERNEL_NAME) ; \
	fi

# Note: current kernel expects init on initramfs on /init, not /sbin/init
initramfs: dirs bbox curl filesystem omf enroll syslinux kexec \
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

.PHONY: all apt-get-update dirs bbox curl omf syslinux getmac enroll \
	kexec filesystem kernel initramfs get_init_cpio get_kernelget_bbox \
	get_syslinux get_kexec install \
	deb apt-install clean mrproper
