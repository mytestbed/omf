#! /bin/sh
#
# starts and stops the Aggregate Manager Daemon (formerly know as gridservices)
#
#     Written by Maximilian Ott <max@winlab.rutgers.edu>.
#     Modified by Christoph Dwertmann
#
### BEGIN INIT INFO
# Provides:          omf-aggmgr
# Required-Start:    $remote_fs $syslog
# Required-Stop:     $remote_fs $syslog
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Short-Description: Start daemon at boot time
# Description:       Enable service provided by daemon.
### END INIT INFO

NAME=omf-aggmgr

test -x /usr/sbin/$NAME || exit 0

if [ -f /etc/$NAME/gridservices.cfg ]; then
   . /etc/$NAME/gridservices.cfg
fi

if [ -f /etc/default/$NAME ]; then
    . /etc/default/$NAME
fi

PORT=`echo $OPTS | sed 's/[^0-9]*//g'`
start(){
        echo -n "Starting OMF Aggregate Manager: $NAME"
	if [ `netstat -ltn | grep $PORT -c` -ne 0 ] ; then
	   echo "\nPort $PORT is in use. There might already be an AM running on this port."
	   exit 1
	fi
	start-stop-daemon --start --background --pidfile /var/run/$NAME.pid --make-pidfile --exec /usr/sbin/$NAME -- $OPTS
        echo "..done."
}

stop(){
        echo -n "Stopping OMF Aggregate Manager: $NAME"
	start-stop-daemon --stop --signal 2 --oknodo --pidfile /var/run/$NAME.pid
	while [ `netstat -ltn | grep $PORT -c` -ne 0 ] ; do
	   echo -n "\nWaiting for release of port $PORT..."
	   sleep 3
	done	
        echo "..done."
}

case "$1" in
  start)
        start
	;;
  stop)
        stop
	;;

  restart)
	stop
	start
	;;

  *)
	echo "Usage: /etc/init.d/$NAME {start|stop|restart}"
	exit 1
esac

exit 0
