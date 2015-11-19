#!/bin/bash

slave_ip="$1"
master_ip="$2"
slave_id="$3"
old_master_id="$4"

recovery_file="/var/lib/pgsql/9.2/data/recovery.conf"
username="postgres"
password="wordpass1"

if [ $slave_id = $old_master_id ]; then
	/usr/bin/pcp_detach_node 10 localhost 9898 $username $password $slave_id
	exit 0
fi

cmd_1="service postgresql-9.2 stop && rm -rf /var/lib/pgsql/9.2/data/ && /usr/pgsql-9.2/bin/pg_basebackup -h $master_ip -D /var/lib/pgsql/9.2/data -U postgres -v -P -x"

cat > /tmp/recovery_$slave_ip <<EOF
standby_mode = 'on'
primary_conninfo = 'host=$master_ip port=5432 user=postgres'
trigger_file = '/tmp/trigger_file'
restore_command = 'cp /var/lib/pgsql/pg_log_archive/%f %p'
EOF

cmd_2=$(cat <<EOF
rm -rf /tmp/trigger_file
chown -R postgres.postgres /var/lib/pgsql/ ;
service postgresql-9.2 start
EOF
)

ssh root@$slave_ip "$cmd_1"
scp /tmp/recovery_$slave_ip root@$slave_ip:$recovery_file
ssh root@$slave_ip "$cmd_2"


#sleep 1

/usr/bin/pcp_attach_node 10 localhost 9898 $username $password $slave_id
