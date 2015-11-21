#!/bin/bash

. /etc/init.d/functions

master_ip=$1
slave_ip=$2

recovery_file="/var/lib/pgsql/9.2/data/recovery.conf"
username="postgres"
password="wordpass1"

cmd_1="service postgresql-9.2 stop && rm -rf /var/lib/pgsql/9.2/data/ && /usr/pgsql-9.2/bin/pg_basebackup -h $master_ip -D /var/lib/pgsql/9.2/data -U postgres -v -P -x"

cat > /tmp/recovery_conf <<EOF
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
scp /tmp/recovery_conf root@$slave_ip:$recovery_file
ssh root@$slave_ip "$cmd_2"
