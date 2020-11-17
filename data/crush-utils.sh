
#
# The following 4 arrays represent a single array with structure elements that we use for holding
# crush bucket information (parent, node name, node type, node index) - this is enough information
# for testing later whether a pool has read affinity (in addition to the type of the failure domain
# level).
#
declare -A crush_parents_by_id
declare -A crush_node_type_by_id
declare -A crush_node_name_by_id
declare -A node_indices_by_id

failure_domain_type=""
failure_domain_num=0
declare -A failure_domains

##
# Common efinitions for nicer outout
##
red_text="\e[1;31m"
green_text="\e[1;32m"
blue_text="\e[1;34m"
reset_text="\e[0m"

function echo_error() {
    echo -e "$red_text*Error*: $reset_text$1"
}

function find_failure_domains()
{
    # 
    # This function finds the first level in the tree which has more than one node. (so root/region/AZ works 
    # as well as root/AZ or root/datacenter and marks it as the failure domain level)
    # It gets one input parameter which is the json file which is the output of the command
    # "ceph osd crush tree -f json"
    #
    if [ -z "$1" ]; then
        echo_error "No paremeter passed to $0"
        exit 0
    fi
    local node_idx=0
    while true; do
        local node_info=$(echo $1 | jq .nodes[$node_idx])
        local n_children=$(echo $node_info | jq ".children | length")
        ## echo "node index $node_idx, nChildren $n_children"
        first_child=$(echo $1 | jq .nodes[$node_idx].children[0])
        if [ $n_children -gt 1 ]; then
            ## echo "node $node_id - below is failure domain, such as $first_child"
            failure_domain_type=${crush_node_type_by_id[$first_child]}
            ## echo "Failure domain type is $failure_domain_type"
            ##failure_domain_num=$n_children
            ##for (( i = 0 ; i < )); do
            ##    local cur_child_id=$(echo $1 | jq .nodes[$node_idx].children[$i])
            ##    failure_domains[${crush_node_name_by_id[$cur_child_id]}]="1"
            ##done
            break
        elif [ $n_children -eq 1 ]; then
            node_idx=${node_indices_by_id[$first_child]}
        else 
            echo_error "Did not find a failure domain in tree. Is this a production-like system?"
            exit 0
        fi
    done
}

function build_crush_tree() {
    ## 
    # This function builds the crush tree information in the 3 arrays
    # crush_parents_by_id, crush_node_type_by_id and crush_node_name_by_id
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
        ##echo "node $id: name is $name, type is $type, index is $i"
        crush_node_name_by_id[$id]=$name
        crush_node_type_by_id[$id]=$type
        node_indices_by_id[$id]=$i
        for (( child = 0 ; child < $n_children ; child++ ))
        do
            local ch_id=$(echo $node_info | jq .children[$child])
 ##           echo "Parent of $ch_id is $id"  
            crush_parents_by_id[$ch_id]=$id
        done
    done    
}

