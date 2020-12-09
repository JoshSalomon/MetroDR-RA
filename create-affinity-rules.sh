#!/bin/bash

##
#TODO:
# 1. Add option to create a pool for specific OSD class (hdd/ssd)
#
##
base_dir=$(dirname "$0")
data_dir=$base_dir/data

. $data_dir/crush-utils.sh

verbose=0
template_dir=data
template_3azs=3az-template-rule.txt
template_2azs=2az-template-rule.txt
rule_suffix=-affinity.rule

debug=0
opts="1:2:3:h"
dbg_opts="vxd"
base_dir="."

function get_max_rule()
{
    #
    # This function prints the largest rule_id
    # use it as max_rule=$(get_max_rule) - so any rule_id larger than $max-rule is guaranteed
    # to not exist
    #
    
    ###
    #TODO: add here the ceph osd crush rule dump command - 'ceph osd crush rule dump | grep "rule_id"
    # it is replaces with a cat command for simplicity and tests
       
##    cat  $base_dir/$template_dir/rule_test.txt | awk '{print $2}' | sed "s/,//" | awk 'BEGIN {max=-1000;} { if ($1 > max) {max=$1;} } END {print max }'
    ceph osd crush rule dump |  awk 'BEGIN {max=-1000} /rule_id/ {gsub(",",""); if ($2 > max) {max=$2;} } END {print max}'
}

function usage() {
    #
    # This function always exits, it never returns
    ###Del if no parameters are passed an empty line is printed before the massage, if any 
    ###Del parameter is passed, the new line is skipped.
    #
###Del    if [ $# -eq 0 ]
###Del    then
###Del        echo
###Del    fi
    echo 
    if [[ $debug == 0 ]]; then
        echo "Usage: $0 -1 az1-class -2 az2-class {-3 az3-class}"
    else
        echo "Usage: $0 debug -1 az1-class -2 az2-class {-3 az3-class} {-v} {-x} {-d}"
    fi
    echo "  -1  Name of first az class (for the crush rules)"
    echo "  -2  Name of second az class (for the crush rules)"
    echo "  -3  Name of thirs az class (for the crush rules) - optional"
    if [[ $debug > 0 ]]; then
        echo "  -v  Debug: Turn verbosity on"
        echo "  -x  Debug: Print command traces before executing command"
        echo "  -d  Debug: Print shell input lines as they are read"
    fi
    (($verbose == 1)) && echo "Verbosity on"
    (($verbose == 1)) && echo "Exiting script"
    echo
    exit 1
}

function check_params() {
    #
    # Check script parameters, if there are errors a message is printed and the script exits (in usage)
    # If the function returns the parameters are OK
    #
    (($verbose == 1)) && echo "az1-class="$az1
    (($verbose == 1)) && echo "az2-class="$az2
    if [ -n "${az3}" ]; then
        (($verbose == 1)) && echo "az3-class="$az3
    fi
    
    if [[ "${az1}" == "" || "${az2}" = "" ]]; then
    
        echo_error "az1-class and az2-class are mandatory parameters"
        usage
    fi

    if [[ "$az1" == "$az2" || "$az1" == "$az3"  ||  "$az2" == "$az3" ]]; then
        echo_error "az-class names should be unique"
        usage
    fi
}

function create_3azs_rule() {
    local id=$1
    local az1=$2
    local az2=$3
    local az3=$4
    cat $base_dir/$template_dir/$template_3azs | sed "s/<<AZ1>>/$az1/" | sed "s/<<AZ2>>/$az2/" | sed "s/<<AZ3>>/$az3/" | sed "s/<<ID>>/$id/"
    
}

###
# Start of script execution (main if you like)
###
base_dir=$(dirname "$0")

if [[ "$1" == "debug" ]]; then
    opts=$opts$dbg_opts
    debug=1
    shift 1
fi

while getopts $opts o; do
    case "${o}" in
        1)
            az1=${OPTARG}
            (($verbose == 1)) && echo "az1-class="$az1
            ;;
        2)
            az2=${OPTARG}
            (($verbose == 1)) && echo "az2-class="$az2
            ;;
        3)
            az3=${OPTARG}
            (($verbose == 1)) && echo "az3-class="$az3
            ;;
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
        h)  usage nosapce
            ;;
        *)
            echo_error "Urecognized parameter "${o}
            usage
            ;;
    esac
done
shift $((OPTIND-1))

check_params

(($verbose == 1)) && echo "*** Parsed command line ***"

max_rule=$(get_max_rule)
(($verbose == 1)) && echo "max_rule="$max_rule

error=0

if [[ "$az3" == "" ]]; then
    echo_error "==> 2 AZs - not implemented yet"
else
    (($verbose == 1)) && echo "==> 3 AZs"
    azs=($az1 $az2 $az3)
    for i in 0 1 2;
    do
        ((max_rule++))
        i2=$(( (i+1) % 3 ))
        i3=$(( (i+2) % 3 ))
        ofile=$base_dir/${azs[$i]}$rule_suffix
        create_3azs_rule $max_rule ${azs[$i]} ${azs[$i2]} ${azs[$i3]} > $ofile
        if [[ $? == 0 ]]; then
            echo "Rule file $ofile created successfully." 
        else
            echo_error "Failed writing $ofile, error code is $?"
            error=1
        fi
    done
fi

if [[ $error == 1 ]]; then 
    echo "Errors found, exiting"
    exit 1
fi
##
# step 1 - Set the crush map correctly
##
##TODO: how to manage this automatically?
##
echo "$0 completed successfully."


