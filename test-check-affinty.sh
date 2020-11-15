#!/bin/bash
#
# test suite for the script check-pool-affinity.shell
#
data_dir=jsalomon

ntests=1
read -n 1 -s -r -p "$ntests. Missing patameters"
echo ""
(( ntests++ )) && ./check-pool-affinity.sh

read -n 1 -s -r -p "$ntests. Wrong pool name"
echo ""
(( ntests++ )) && ./check-pool-affinity.sh NonExistingPool

read -n 1 -s -r -p "$ntests. Simple tests on rbd"
echo ""
(( ntests++ )) && ./check-pool-affinity.sh rbd

read -n 1 -s -r -p "$ntests. Test on manipulated json file"
echo ""
(( ntests++ )) && ./check-pool-affinity.sh rbd $data_dir/crush-tree-plain.json

read -n 1 -s -r -p "$ntests. Test on original json file"
echo ""
(( ntests++ )) && ./check-pool-affinity.sh rbd $data_dir/crush-tree-plain.json.original


read -n 1 -s -r -p "$ntests. Test on non exiting json file"
echo ""
(( ntests++ )) && ./check-pool-affinity.sh rbd NonExistingFile

if [[ "$USER" != "root" ]]; then
    read -n 1 -s -r -p "$ntests. Test on non readable json file (applicable to non-root users only)"
    echo ""
    temp_file=$(mktemp)
    cp  $data_dir/crush-tree-plain.json $temp_file ; chmod -r $temp_file
    ls -a $temp_file
    (( ntests++ )) && ./check-pool-affinity.sh rbd $temp_file
    chmod +r $temp_file ; rm $temp_file
fi



