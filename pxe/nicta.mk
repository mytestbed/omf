# include file to override variables for use at NICTA
# symlink this file as "site.mk" for it to be effective
#   The first group of variables defines the apt-get or wget URL
#    to fetch locally cached deb packages:
#   URL = $APT_HOST/$WINLAB_REP  (or MAIN_REP for main section)
APT_HOST = http://203.143.174.94
WINLAB_REP = dists/testing/winlab/binary-i386
MAIN_REP = dists/testing/main/binary-i386
KEXEC_REP = dists/testing/main/binary-i386

#   The next group of variables defines the scp target to copy
#    files into the local repository.
#   scp target = $REPOSITORY:$REPOSITORY_ROOT/$APP_PATH
#    APP_PATH is determined in the Makefile, by examining the changelog
REPOSITORY = $(USER)@norbit.npc.nicta.com.au
REPOSITORY_ROOT = /var/www/dists
#
# Finally, you can override the default config files for kernel and busybox.
# NICTA uses different hardware, therefore needs a different kernel config
# Also has more tools in the busybox config (fewer nodes, not so concerned
# with the PXE image size, need to support SATA disks, PATA disks,
# & USB flash drives):
BBOX_VERSION = 1.16.0
BBOX_CONFIG_FILE = busybox-nicta.config
