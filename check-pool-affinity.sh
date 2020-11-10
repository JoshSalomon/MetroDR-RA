#!/bin/bash

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

pool_num=$(ceph osd pool stats | awk -v PN="$pool_name" '{ if ($1 == "pool" && $2 == PN) {print $4}}')

echo " == Pool num = $pool_num"

##
# Get the list of primary OSDs for this pool, string of OSD IDs separated by ':' sign
#

primaries=$(ceph pg dump pgs_brief 2>/dev/null | grep "^$pool_num." | awk '{ split($3, a, "[\\[\\],]", sep); print  a[2]}')
primaries=$(echo $primaries | sed "s/ /:/g")

echo " == Primaries"
echo "$primaries"

##
# Generate an array out of the string for rasier manipulation
#
prim_count=0
IFS=':' read -ra prim_array <<< "$primaries"
for p in "${prim_array[@]}"; do
        # Do some processing here
        ((prim_count++))
done
echo " == Iterated over $prim_count PGs"


