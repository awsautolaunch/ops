#!/bin/bash

node_type="$1"
file_name="$2"


function usage {
    echo "Usage : $(basename $0) <node_type> <template_file>" && exit 1
}

[[ -z "$node_type" ]] && usage
[[ -z "$file_name" ]] && usage

sed "s/CHEF_ROLE_PLACE_HOLDER/$node_type/" userdata.tmpl
