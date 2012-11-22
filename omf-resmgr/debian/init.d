#! /bin/sh
#
# starts and stops the Resource Manager Daemon 
#     Written by Maximilian Ott <max@winlab.rutgers.edu>.
#     Modified by Thierry Rakotoarivelo
#

### BEGIN INIT INFO
# Provides:          omf-resmgr
# Required-Start:    $remote_fs $syslog
# Required-Stop:     $remote_fs $syslog
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Short-Description: Start daemon at boot time
# Description:       Enable service provided by daemon.
### END INIT INFO

NAME=omf-resmgr-5.4

test -x /usr/sbin/$NAME || exit 0

if [ -f /etc/$NAME/$NAME.cfg ]; then
   . /etc/$NAME/$NAME.cfg
fi

if [ -f /etc/default/$NAME ]; then
    . /etc/default/$NAME
fi

start(){
    echo -n "Starting OMF Resource Manager: $NAME"
	if [ -f /var/log/$NAME.log ]; then
	    mv /var/log/$NAME.log /var/log/$NAME.log.1
	fi
	start-stop-daemon --start --quiet --background --pidfile /var/run/$NAME.pid --make-pidfile --exec /usr/sbin/$NAME -- $OPTS
    echo "."
}

stop(){
    echo -n "Stopping OMF Resource Manager: $NAME"
	start-stop-daemon --stop --quiet --oknodo --pidfile /var/run/$NAME.pid
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
  force-reload)
    stop
    start
    ;;

  *)
	echo "Usage: /etc/init.d/$NAME {start|stop|restart|force-reload}"
	exit 1
esac

exit 0
