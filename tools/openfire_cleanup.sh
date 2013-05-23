# warning: this script will clear almost all Openfire database tables
# it will keep the 'admin' and 'aggmgr' user accounts

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
truncate ofOffline;
truncate ofPubsubAffiliation;
truncate ofPubsubDefaultConf;
truncate ofPubsubNode;
delete from ofUser where username not like 'aggmgr%' and username != 'admin';
quit
EOF
