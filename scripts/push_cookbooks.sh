#!/bin/bash

tar_file=""
coobooks_version_file="/tmp/cookbooks_version"
s3_chef_path="s3://tt-assignment/ops/chef"
pull_script_path="../cookbooks/base/files/default/pull_script.sh"

function checkForUnCommittedChanges {
    git diff --quiet HEAD
    [[ $? -ne 0 ]] && exitWithMessage "Please commit pending changes to proceed." 1
}

function exitWithMessage {
    echo "$1"
    exit "$2"
}

function getCurrentGitRevision {
    echo $(git rev-parse HEAD)
}

function prepareFilesForSync {
    current_revision="$(git rev-parse HEAD)"
    tar_file="$current_revision.tgz"
    [[ -f $tar_file ]] && rm -rf "../$tar_file"
    tar -cvzf $tar_file "../cookbooks" > /dev/null
    echo $current_revision > $coobooks_version_file
}

function pushFilesToS3 {
    aws s3 cp $tar_file "$s3_chef_path/cookbooks/$tar_file"
    aws s3 cp $pull_script_path "$s3_chef_path/scripts/pull_script.sh"
    aws s3 cp bootstrap.sh "$s3_chef_path/scripts/bootstrap.sh"
    aws s3 cp $coobooks_version_file "$s3_chef_path/cookbooks/cookbook_version"
    rm -rf $tar_file
}


# Move to script directory.
cd $(dirname $0)
checkForUnCommittedChanges
prepareFilesForSync
pushFilesToS3
