#!/bin/bash

set -x

# run_list
run_list="$1"


s3_chef_path="s3://tt-assignment/ops/chef"
chef_dir="/opt/ops/chef"

mkdir -p $chef_dir
echo $run_list > $chef_dir/run_list

aws s3 cp $s3_chef_path/scripts/pull_script.sh $chef_dir/pull_script.sh

bash -x $chef_dir/pull_script.sh
