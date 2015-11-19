#!/bin/bash

KEY="$1"
VALUE="$2"
EC2_AVAIL_ZONE=`curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone`
EC2_REGION="`echo \"$EC2_AVAIL_ZONE\" | sed -e 's:\([0-9][0-9]*\)[a-z]*\$:\\1:'`"
RESOURCES="$(curl -s http://169.254.169.254/latest/meta-data/instance-id)"
GROUP_NAME="$(cat /opt/ops/chef/run_list)"

aws ec2 create-tags --region $EC2_REGION --resources $RESOURCES --tags Key=$KEY,Value=$VALUE
