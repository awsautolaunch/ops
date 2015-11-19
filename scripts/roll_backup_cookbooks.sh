#!/bin/bash

new_revision="$1"

coobooks_version_file="/tmp/cookbooks_version"
s3_chef_path="s3://tt-assignment/ops/chef"

[[ -z "$new_revision" ]] && echo "Usage : $(basename $0) <rollback_version>" && exit 1

echo $new_revision > $coobooks_version_file
aws s3 cp $coobooks_version_file "$s3_chef_path/cookbooks/cookbook_version"
