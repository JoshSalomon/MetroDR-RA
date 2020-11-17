#!/bin/bash

#
# test suite for the script create_affinity_rules.sh
#
base_dir=$(dirname "$0")/..
data_dir=$base_dir/data
tested_script=create-affinity-rules.sh

blue_text="\e[1;34m"
reset_text="\e[0m"

run_one_by_one=0

function usage() {
    echo ""
    echo "Usage: $(basename "$0") [one]"
    echo "       Runs a series of tests for the $tested_script script."
    echo "optional argumaents:"
    echo "  one    Run the tests one by one (need to hit key after each test name to execute it)"
    echo ""
}

function run_test() {
    local cmd=$1
    echo -e "\nExecuting '$cmd':"
    $base_dir/$cmd    
}

function echo_test_name() {
    echo -e "$blue_text$ntests. $1$reset_text"
    if [[ $run_one_by_one > 0 ]]; then
        read -n 1 -s -r -p ""
    fi
}

if [[ "$1" == "one" ]]; then 
    run_one_by_one=1
elif [[ "$1" != "" ]]; then
    usage
    exit
fi

ntests=1
echo_test_name "Missing patameters (1)"
run_test "$tested_script"

(( ntests++ )) && echo_test_name "Missing patameters (2)"
run_test "$tested_script -1 abc"

(( ntests++ )) && echo_test_name "Missing patameters (3)"
run_test "$tested_script -3 bca -1 abc"

(( ntests++ )) && echo_test_name "Missing patameters (4)"
run_test "$tested_script -2 abc"

(( ntests++ )) && echo_test_name "Missing patameters (5)"
run_test "$tested_script -3 bca -2 abc"

(( ntests++ )) && echo_test_name "Identical AZs (1)"
run_test "$tested_script -1 bca -2 bca"

(( ntests++ )) && echo_test_name "Identical AZs (2)"
run_test "$tested_script -1 bca -2 abc -3 bca"

(( ntests++ )) && echo_test_name "Identical AZs (3)"
run_test "$tested_script -1 bca -2 abc -3 abc"

(( ntests++ )) && echo_test_name "Create rules for 2 AZs"
run_test "$tested_script -1 bca -2 abc"

(( ntests++ )) && echo_test_name "Create rules for 3 AZs"
run_test "$tested_script -1 bca -3 zzz -2 abc"

