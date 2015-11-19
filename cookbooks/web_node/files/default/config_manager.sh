#!/bin/bash

jobs_dir="/var/www/html/jobs/";
lock_file="$jobs_dir.running";

[[ -f $lock_file ]] && echo "Already running..." && exit 0
touch $lock_file

count=$(ls $jobs_dir | wc -l)
[[ $count -ne 0 ]] && php /opt/ops/config_manager/config_manager.php
unlink $lock_file
