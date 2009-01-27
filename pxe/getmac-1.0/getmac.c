/*
 *  Copyright (C) 2007 Luis R. Rodriguez <mcgrof@winlab.rutgers.edu>
 *
 *  This program is free software; you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation; either version 2 of the License
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with this program; if not, write to the Free Software
 *  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
 *
 * getmac: smal app (~9K) to print device mac address, saves you some bytes 
 * if you do not want to include awk (about 300K) on a system to parse 
 * 'ip addr list' or 'ifconfig' output.
 *
 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>
#include <unistd.h>
#include <net/if.h>
#include <errno.h>
#include <sys/ioctl.h>
#include <sys/socket.h>
#include <linux/if_ether.h>

/* MAC address + 5 colons, ie: 00:0a:0b:de:ef:ff */
#define ETH_ALEN_LONG	ETH_ALEN * 2 + 5
#define APP "getmac"
#define VERSION	"1.0"
#define USAGE APP " [-u | --upper-case] [-h | --help] <device>"
#define INSTRUCTIONS USAGE  \
	"\n" APP "-" VERSION " - small app (~9K) to print device mac address" \
	"\n-u|--upper-case\tUppercase MAC address string" \
	"\n-h|--help\tHelp menu\n"

/* We support only up to ETH_ALEN_LONG though as that's all we'll need */
char * strupr(const char *str)
{
	char *ustr;
	int i, len = strlen(str);;
	if(len <= 0 || len > ETH_ALEN_LONG)
		return NULL;
	ustr = (char *) malloc(ETH_ALEN_LONG);
	memset(ustr, 0, ETH_ALEN_LONG);
	for(i=0; i<len; i++) {
		if(isalpha(str[i]))
			ustr[i] = (char) toupper(str[i]);
		else
			ustr[i] = (char) str[i];
	}
	return ustr;
}

int main(int argc, char **argv)
{
	int fd;
	int upper = 0;
	struct ifreq ifr;
	char mac[ETH_ALEN_LONG];
	char *dev;
	if(argc>3) {
		printf(USAGE "\n");
		exit(1);
	}
	if(argc==2) {
		if(strcmp(argv[1], "-h")==0 || strcmp(argv[1], "--help")==0)  {
			printf(INSTRUCTIONS);
			return 0;
		}
		if(strcmp(argv[1], "-u")==0 || strcmp(argv[1], "--upper-case")==0) {
			printf(USAGE "\n");
			exit(1);
		}
		dev = (char *) argv[1];
	}
	if(argc==3) {
		if(strcmp(argv[1], "-u")==0 || strcmp(argv[1], "--upper-case")==0) {
			upper = 1;
			dev = (char *) argv[2];
		}
		else {
			printf(USAGE "\n");
			exit(1);
		}
	}
	fd = socket(PF_INET, SOCK_DGRAM, 0);
	strcpy(ifr.ifr_name, dev); /* eth0, ath0, wlan0, etc */
	if(ioctl(fd, SIOCGIFHWADDR, &ifr) < 0) { /* retrieve MAC address */
		close(fd);
		perror("ioctl[SIOCGIFHWADDR]");
		exit(1);
	}
	sprintf(mac, "%02x:%02x:%02x:%02x:%02x:%02x",
			(unsigned char)ifr.ifr_hwaddr.sa_data[0],
			(unsigned char)ifr.ifr_hwaddr.sa_data[1],
			(unsigned char)ifr.ifr_hwaddr.sa_data[2],
			(unsigned char)ifr.ifr_hwaddr.sa_data[3],
			(unsigned char)ifr.ifr_hwaddr.sa_data[4],
			(unsigned char)ifr.ifr_hwaddr.sa_data[5]);
	if(upper)
		printf("%s\n", strupr(mac));
	else
		printf("%s\n", mac);
	close(fd);
	return 0;
}
