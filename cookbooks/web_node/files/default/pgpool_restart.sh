#!/bin/bash

pgpool reload

sleep 3
args=" 10 localhost 9898 postgres wordpass1 "
count=$(pcp_node_count $args)
(( count-- ))
seq 0 $count | xargs -I__ pcp_attach_node $args __
