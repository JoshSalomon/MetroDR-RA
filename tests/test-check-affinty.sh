#!/bin/bash
#
# test suite for the script check-pool-affinity.sh
#
base_dir=$(dirname "$0")/..
data_dir=$base_dir/data
tested_script=check-pool-affinity.sh

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
echo_test_name "Missing patameters"
run_test "$tested_script"

(( ntests++ )) && echo_test_name "Wrong pool name"
run_test "$tested_script NonExistingPool"


(( ntests++ )) && echo_test_name "Simple tests on rbd"
run_test "$tested_script rbd"

(( ntests++ )) && echo_test_name "Test on non exiting json file"
run_test "$tested_script rbd NonExistingFile"

echo -e "\n*****************************************************************************************************"
echo -e   "***$blue_text The rest of the tests work only when the json file fits the existing ceph system.             $reset_text***"
echo -e   "***$blue_text You can enable them (by editing this script) once you build the json file out of the commnad: $reset_text***"
echo -e   "*** ==> ceph osd crush tree -f json <==                                                           ***"
echo -e   "*** This is required only when you want to test against a crush tree structure which differs      ***"
echo -e   "*** from your live system configuration.                                                          ***"
echo -e   "*****************************************************************************************************\n"
##
#TODO:
# change the following line once you have a good json file, set skip_file_tests to 0
##
skip_file_tests=1

if [[ $skip_file_tests == 0 ]]; then
	(( ntests++ )) && echo_test_name "Test on manipulated json file"
	run_test "$tested_script rbd $data_dir/crush-tree-plain.json"

	(( ntests++ )) && echo_test_name "Test on manipulated json file (Skip pool existence test)"
	run_test "$tested_script rbd $data_dir/crush-tree-plain.json -f"

	(( ntests++ )) && echo_test_name "Test on original json file"
	run_test "$tested_script rbd $data_dir/crush-tree-plain.json.original"

	if [[ "$USER" != "root" ]]; then
    	(( ntests++ )) && echo_test_name "Test on non readable json file (applicable to non-root users only)"
	    echo ""
    	temp_file=$(mktemp)
	    cp  $data_dir/crush-tree-plain.json $temp_file ; chmod -r $temp_file
    	ls -a $temp_file
	    run_test "$tested_script rbd $temp_file"
    	chmod +r $temp_file ; rm $temp_file
	fi
fi

echo -e "\nCompleted $ntests tests."


