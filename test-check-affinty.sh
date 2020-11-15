#!/bin/bash
#
# test suite for the script check-pool-affinity.shell
#
data_dir=jsalomon

blue_text="\e[1;34m"
reset_text="\e[0m"

function run_test() {
    local cmd=$1
    echo -e "\nExecuting '$cmd':"
    $cmd    
}

function echo_test_name() {
    echo -e "$blue_text$ntests. $1$reset_text"
    read -n 1 -s -r -p ""
}
ntests=1
echo_test_name "Missing patameters"
run_test "./check-pool-affinity.sh"

(( ntests++ )) && echo_test_name "Wrong pool name"
run_test "./check-pool-affinity.sh NonExistingPool"


(( ntests++ )) && echo_test_name "Simple tests on rbd"
run_test "./check-pool-affinity.sh rbd"

(( ntests++ )) && echo_test_name "Test on manipulated json file"
run_test "./check-pool-affinity.sh rbd $data_dir/crush-tree-plain.json"

(( ntests++ )) && echo_test_name "Test on original json file"
run_test "./check-pool-affinity.sh rbd $data_dir/crush-tree-plain.json.original"

(( ntests++ )) && echo_test_name "Test on non exiting json file"
run_test "./check-pool-affinity.sh rbd NonExistingFile"

if [[ "$USER" != "root" ]]; then
    (( ntests++ )) && echo_test_name "Test on non readable json file (applicable to non-root users only)"
    echo ""
    temp_file=$(mktemp)
    cp  $data_dir/crush-tree-plain.json $temp_file ; chmod -r $temp_file
    ls -a $temp_file
    run_test "./check-pool-affinity.sh rbd $temp_file"
    chmod +r $temp_file ; rm $temp_file
fi

echo -e "\nCompleted $ntests tests."


