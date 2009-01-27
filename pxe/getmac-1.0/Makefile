getmac: getmac.c
	gcc -Wall -o getmac getmac.c

install: getmac
	cp getmac $(DESTDIR)/usr/sbin/

clean:
	rm -f getmac
