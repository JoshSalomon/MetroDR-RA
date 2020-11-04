#!/bin/bash

verbose=0 

function usage() {
    #
    echo 
    echo "Usage: $0 TBD"
    echo
    exit 1
}

input_file=""
while getopts "v:hf:" o; do
    case "${o}" in
        v)
            verbose=${OPTARG}
            (($verbose >= 1)) && echo "Running in verbose mode, level=$verbose" 
            ;;
        h)  
            usage 
            ;;
        f)  
            input_file=${OPTARG}
            (($verbose >= 1)) && echo "Input file is $input_file"
            [ ! -f $input_file ] && { echo "*ERROR*: File $input_file does not exist"; usage; }
            [ ! -r $input_file ] && { echo "*ERROR*: File $input_file is not readable"; usage; }
            ;;
        *)  
            echo "*ERROR*: Urecognized parameter "${o}
            usage
            ;;
    esac
done

[ -z "$input_file" ] && { echo "*ERROR*: Mandatory parameter input_file is missing"; usage; }

cat $input_file | awk -v verbose=$verbose 'BEGIN { FS= "," ; }
FNR > 0 {
    if ($2 in osds) {
        osds[$2] = osds[$2] ","  $1
    } else {
        osds[$2]=$1
    }
}
END {
    nrows = 0;
    for (az in osds) {
       if (verbose > 10) {
           printf("OSD %s in AZ %s\n", osds[az], az);
       }
       if (verbose > 0) {
           printf("= AZ %s\n", az);
       }
       output[nrows] = az;
       sep = ":";
       split(osds[az], osd_array, ",");
       for (osd in osd_array) {
          if (verbose > 0) {
             printf("+=> OSD %s\n", osd_array[osd]);
          }
          output[nrows] = output[nrows] sep osd_array[osd];
          sep = ",";
       }
        nrows++;
    }
    for (i = 0 ; i < nrows ; i++) {
        printf("%s\n", output[i]);
    }
}'
 
