#!/bin/bash

#####
# Note to reader:
# This script should have been written in Python. In order to make it more portable and not to mess
# with various dependencies and installation, I decided to develop it in bash, with only one 
# dependency, (jq version 1.6). It makes the sctipt more complex, and a bit more difficult to 
# develop and possibly maintain, but it should prevent many of the typical version/dependencies 
# issues with Python and since this script is meant to be used very rarely, it was worth this 
# extra development effort.
#####

#
# The following 4 arrays represent a single array with structure elements that we use for holding
# crush bucket information (parent, node name, node type, node index) - this is enough information
# for testing later whether a pool has read affinity (in addition to the type of the failure domain
# level).
#
declare -A crush_parents
declare -A crush_node_type
declare -A crush_node_name
declare -A node_indices

failure_domain_type=""

function usage() {
    #
    echo 
    echo "Usage: $0 pool_name"
    echo
    echo "Check if pool_name has read affinity (all its primary OSDs are from the same datacenter"
    echo "or availability zone)"
    echo
    exit 1
}

function find_failure_domain()
{
    # 
    #TODO - the first level in the tree which has more than one node. (so root/region/AZ works 
    # as well as root/AZ or root/datacenter)
    echo "" > /dev/null
    local node_idx=0
    while true; do
        local node_info=$(echo $1 | jq .nodes[$node_idx])
        local n_children=$(echo $node_info | jq ".children | length")
        echo "node index $node_idx, nChildren $n_children"
        first_child=$(echo $1 | jq .nodes[$node_idx].children[0])
        if [ $n_children -gt 1 ]; then
            echo "node $node_id - below is failure domain, such as $first_child"
            failure_domain_type=${crush_node_type[$first_child]}
            echo "Failure domain type is $failure_domain_type"
            break
        elif [ $n_children -eq 1 ]; then
            node_idx=${node_indices[$first_child]}
        else 
            echo "*ERROR*: Did not find a failure domain in tree. Is this a production-like system?"
            exit 0
        fi
    done
}

function has_read_affinity() {
    echo "" > /dev/null
    ##local prim_count=0
    local failure_domain=""
    IFS=':' read -ra prim_array <<< "$primaries"
    for p in "${prim_array[@]}"; do
        # Do some processing here
        ##((prim_count++))
        ##echo "Checking primary $p"
        local node_id=$p
        while [ "${crush_node_type[$node_id]}" != "$failure_domain_type"  ]; do
            node_id=${crush_parents[$node_id]}
        done
        
        if [ -z "$failure_domain" ]; then
            failure_domain=${crush_node_name[$node_id]}
        elif [ $failure_domain !=  ${crush_node_name[$node_id]} ]; then
            echo -e "\nPool $pool_name does not have read affinity\n"
            return
        fi

        ##echo "Failure domain for $p is ${crush_node_name[$node_id]}"
    done
    echo -e "\nPool $pool_name has read affinity to failure domain $failure_domain\n"    
    ##echo " == Iterated over $prim_count PGs"
}

function build_crush_tree() {
    ## 
    # This function builds the crush tree information in the 3 arrays
    # crush_parents, crush_node_type and crush_node_name
    ##
    local num_nodes=$(echo $1 | jq ".nodes | length")
##    echo " found $num_nodes nodes in the crush tree"

    for  (( i = 0 ; i < $num_nodes ; i++ ))
    do
        local node_info=$(echo $1 | jq .nodes[$i])
##        echo "====="
##        echo $node_info
##        echo "-----"
        local n_children=$(echo $node_info | jq ".children | length")
        local id=$(echo $node_info | jq .id)
        local type=$(echo $node_info | jq .type | sed 's/"//g')
        local name=$(echo $node_info | jq .name | sed 's/"//g')
        echo "node $id: name is $name, type is $type, index is $i"
        crush_node_name[$id]=$name
        crush_node_type[$id]=$type
        node_indices[$id]=$i
        for (( child = 0 ; child < $n_children ; child++ ))
        do
            local ch_id=$(echo $node_info | jq .children[$child])
 ##           echo "Parent of $ch_id is $id"  
            crush_parents[$ch_id]=$id
        done
    done    
    
}

if [ -z "$1" ]; then
    usage
fi

pool_name=$1
###
# Check that the pool exists
#
ceph osd pool get $pool_name size &> /dev/null
if [ $? -ne 0 ]; then
    echo
    echo "*ERROR*: Pool $pool_name does not exist"
    usage
fi

echo " == Checking affinity for pool $pool_name"

if [ -z "$2" ]; then
    crush_tree_json=$(ceph osd crush tree -f json)
else
    echo "debug mode"
    if [ -r $2 ]; then
        crush_tree_json=$(cat $2)
    else 
        echo "Cant read $2"  
        exit      
    fi
fi

build_crush_tree $crush_tree_json
find_failure_domain $crush_tree_json

echo "Failure domain type is $failure_domain_type"

##debug
for i in "${!crush_node_name[@]}"; do
    echo "Node $i, name ${crush_node_name[$i]}, type ${crush_node_type[$i]}, parent ${crush_parents[$i]}" 
done

pool_num=$(ceph osd pool stats | awk -v PN="$pool_name" '{ if ($1 == "pool" && $2 == PN) {print $4}}')

echo " == Pool num = $pool_num"

##
# Get the list of primary OSDs for this pool, string of OSD IDs separated by ':' sign
#

primaries=$(ceph pg dump pgs_brief 2>/dev/null | grep "^$pool_num." | awk '{ split($3, a, "[\\[\\],]", sep); print  a[2]}')
#
# Create a list with a single copy of each primary so the test is much faster. The primary list 
# separatoe is colon ':'. This is broken into 2 lines since for some reason the sed in the second 
# line does not work well when piped to the first line 
#
primaries=$(echo $primaries | sed "s/ /\n/g" | sort | uniq )
primaries=$( echo $primaries | sed "s/ /:/g")
echo "short primaries list: $primaries"

has_read_affinity


