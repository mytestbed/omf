#! /bin/sh
#
# nodeagent init script to start nodeagent daemon
#
#     Written by Maximilian Ott <max@winlab.rutgers.edu>.
#
# Version: $Id:$
#

NAME=nodeagent4

test -x /usr/sbin/$NAME || exit 0

if [ -f /etc/$NAME/nodeagent.cfg ]; then
   . /etc/$NAME/nodeagent.cfg
fi

if [ -f /etc/default/$NAME ]; then
    . /etc/default/$NAME
fi


export PATH="${PATH:+$PATH:}/usr/sbin:/sbin"

case "$1" in
  start)
        echo -n "Starting Orbit Nodeagent: $NAME"
	start-stop-daemon --start --quiet --background --pidfile /var/run/$NAME.pid --make-pidfile --exec /usr/sbin/$NAME -- $OPTS
        echo "."
	;;
  stop)
        echo -n "Stopping Orbit Nodeagent: $NAME"
	start-stop-daemon --stop --quiet --oknodo --pidfile /var/run/$NAME.pid
        echo "."
	;;

  reload|force-reload)
	check_for_no_start
	check_config
        echo -n "Reloading Orbit Nodeagent's configuration"
	start-stop-daemon --stop --signal 1 --quiet --oknodo --pidfile /var/run/$NAME.pid --exec /usr/sbin/$NAME
	echo "."
	;;

  restart)
	check_config
        echo -n "Restarting Orbit Nodeagent: $NAME"
	start-stop-daemon --stop --quiet --oknodo --retry 30 --pidfile /var/run/$NAME.pid
	start-stop-daemon --start --quiet --pidfile /var/run/$NAME.pid --exec /usr/sbin/$NAME -- $OPTS
	echo "."
	;;

  *)
	echo "Usage: /etc/init.d/$NAME {start|stop|reload|force-reload|restart}"
	exit 1
esac

exit 0

