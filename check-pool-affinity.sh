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

. $(dirname "$0")/crush-utils.sh

debug=0
verbose=0
input_file=""

function usage() {
    #
    echo 
    if [[ $debug == 0 ]]; then
       echo "Usage: $0 pool_name"
    else
       echo "Usage: $0 pool_name {-v} {-x} {-d}"
    fi
    echo
    echo "Check if pool_name has read affinity (all its primary OSDs are from the same datacenter"
    echo "or availability zone)"
    if [[ $debug > 0 ]]; then
        echo "  -v  Debug: Turn verbosity on"
        echo "  -x  Debug: Print command traces before executing command"
        echo "  -d  Debug: Print shell input lines as they are read"
    fi
    echo
    exit 1
}


function has_read_affinity() {
    ##local prim_count=0
    local failure_domain=""
    IFS=':' read -ra prim_array <<< "$primaries"
    for p in "${prim_array[@]}"; do
        # Do some processing here
        ##((prim_count++))
        ##echo "Checking primary $p"
        local node_id=$p
        while [[ "${crush_node_type[$node_id]}" != "$failure_domain_type"  ]]; do
            node_id=${crush_parents[$node_id]}
        done
        
        if [[ "$failure_domain" == "" ]]; then
            failure_domain=${crush_node_name[$node_id]}
        elif [[ $failure_domain !=  ${crush_node_name[$node_id]} ]]; then
            echo -e "\n => Pool $pool_name does not have read affinity\n";
            return 0
        fi

        ##echo "Failure domain for $p is ${crush_node_name[$node_id]}"
    done
    echo -e "\n => Pool $pool_name has read affinity to failure domain $failure_domain\n";    
    return 1
    ##echo " == Iterated over $prim_count PGs"
}

if [[ "$1" = "debug" ]]; then
    debug=1
    shift 1
fi


if [[ -z "$1" ]]; then
    usage
fi

pool_name=$1
shift 1

if [[ -n "$1" && "${1:0:1}" != "-" ]]; then
    input_file=$1
    shift 1
fi

if [[ $debug > 0 ]]; then
    while getopts "vxdh" o; do
        case "${o}" in
            v)
                verbose=1
                echo "Running in verbose mode" 
                ;;
            x)
                set -x
                echo "Expansion mode on"
                ;;
            d)
                set -v
                echo "Shell verbose mode on"
                ;;
            h)  usage 
                ;;
            *)
                echo "*ERROR*: Urecognized parameter "${o}
                usage
                ;;
        esac
    done
fi

###
# Check that the pool exists
#
ceph osd pool get $pool_name size &> /dev/null
if [[ $? != 0 ]]; then
    echo
    echo "*ERROR*: Pool $pool_name does not exist"
    usage
fi

echo " == Checking affinity for pool $pool_name"

if [[ "$input_file" == "" ]]; then
    crush_tree_json=$(ceph osd crush tree -f json)
else
    echo " == debug mode - reading crush info from file $input_file"
    if [ -r $input_file ]; then
        crush_tree_json=$(cat $input_file)
    else 
        echo "*Error*: Cant read $input_file"  
        exit      
    fi
fi

build_crush_tree $crush_tree_json
find_failure_domains $crush_tree_json

(($verbose == 1)) && echo " == Failure domain type is $failure_domain_type"

##debug
##for i in "${!crush_node_name[@]}"; do
##    echo "Node $i, name ${crush_node_name[$i]}, type ${crush_node_type[$i]}, parent ${crush_parents[$i]}" 
##done

pool_num=$(ceph osd pool stats | awk -v PN="$pool_name" '{ if ($1 == "pool" && $2 == PN) {print $4}}')

(($verbose == 1)) && echo " == Pool num = $pool_num"

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
primaries=$(echo $primaries | sed "s/ /:/g")
##echo "short primaries list: $primaries"

has_read_affinity

