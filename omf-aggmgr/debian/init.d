#! /bin/bash
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

NAME=omf-aggmgr-5.3

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
		echo -e "\nPort $PORT is in use. There might already be a '$NAME' process running."
		exit 0
	fi
	start-stop-daemon --start --background --pidfile /var/run/$NAME.pid --make-pidfile --exec /usr/sbin/$NAME -- $OPTS
	i=0
	while [ `netstat -ltn | grep $PORT -c` -eq 0 ] ; do
		if [ $i -eq 10 ]; then
			echo -e "\nThe $NAME did not start within 10 seconds. Please run '$NAME' on the command line and check '/var/log/$NAME.log' for any errors."
			exit 0
		fi
		sleep 1
		let i++
	done	
	echo "."
}

stop(){
	echo -n "Stopping OMF Aggregate Manager: $NAME"
	if ! [ -e /var/run/$NAME.pid ]; then
		echo -e "\nNo pidfile found."
		return
	fi
	#	start-stop-daemon --stop --signal 9 --oknodo --pidfile /var/run/$NAME.pid
	pid=`cat /var/run/$NAME.pid`
	sid=`ps -p $pid -o sid | awk 'NR==2'`
	if [ ! -n "$sid" ]; then 
		echo -e "\nCould not find the '$NAME' process, '$NAME' might still be running."
		return
	fi
	pkill -9 -s $sid
	i=0
	while [ `netstat -ltn | grep $PORT -c` -ne 0 ] ; do
		if [ $i -eq 5 ]; then
			echo -e "\nPort $PORT is still in use, the '$NAME' process might not have shut down correctly."
			exit 0
		fi
		sleep 1
		let i++
	done	
	echo "."
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
