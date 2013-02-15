if [ $# -lt 2 ]
then
	echo -e "Usage: $0 [MYSQL_USER] [MYSQL_PASSWORD]"
	exit 1
fi
mysql -u$1 -p$2 << EOF
use openfire;
truncate ofPubsubItem;
truncate ofPresence;
truncate ofPubsubSubscription;
delete from ofUser where username not like 'aggmgr%' and username != 'admin';
quit
EOF
