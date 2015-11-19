#!/bin/bash


s3_chef_path="s3://tt-assignment/ops/chef"
chef_dir="/opt/ops/chef"
run_list_file="$chef_dir/run_list"
cookbook_version_file="$chef_dir/cookbook_version"
chef_client="/usr/bin/chef-client"
new_version=""


function checkForUpdates {
    [[ -f "$cookbook_version_file" ]] && compareVersions
    aws s3 cp $s3_chef_path/cookbooks/cookbook_version /tmp/cookbook_version
    new_version="$(cat /tmp/cookbook_version)"
}

function compareVersions {
    aws s3 cp $s3_chef_path/cookbooks/cookbook_version /tmp/cookbook_version
    diff /tmp/cookbook_version $cookbook_version_file > /dev/null
    [[ $? -eq 0 ]] && echo "Cookbooks are upto date." && runCookBooks && exit 0
}

function getLatestChanges {
    tar_file="$new_version.tgz"
    aws s3 cp "$s3_chef_path/cookbooks/$tar_file" $chef_dir/$tar_file
    cd $chef_dir
    rm -rf $chef_dir/cookbooks
    tar -xvzf $tar_file
}

function runCookBooks {
    cd $chef_dir/cookbooks
    $chef_client --local-mode --runlist "recipe[$(cat $run_list_file)]"
    echo $new_version > $cookbook_version_file
}

checkForUpdates
getLatestChanges
runCookBooks
