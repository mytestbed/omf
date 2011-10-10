mysql -uopenfire -popenfire  << EOF
use openfire;
truncate ofPubsubItem;
truncate ofPresence;
truncate ofPubsubSubscription;
delete from ofUser where username not like 'aggmgr%' and username != 'admin';
quit
EOF
