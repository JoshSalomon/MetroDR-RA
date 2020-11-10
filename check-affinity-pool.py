#!/bin/python

import sys
import subprocess

##
#TODO:
# write a function that executes shell command, checks RC and returns the output.
##

def main():
    if sys.version_info < (3, 5):
        print("This script require python version 3.5 of higher -- exiting")
        sys.exit(1) 
    
    print("Hello World")
    
    ## Here should come the command that grabs info from ceph, for debug purpose I use files with
    ## the output here.
    
    ###
    # Example:
    # Call a command
    p = subprocess.Popen("ls -la | grep rule", stdout=subprocess.PIPE, shell=True)
    # Talk with the command i.e. read data from stdout and stderr. Store this info in tuple 
    # Interact with process: Send data to stdin. Read data from stdout and stderr, until end-of-file is reached.  
    # Wait for process to terminate. The optional input argument should be a string to be sent to the child process,
    # or None, if no data should be sent to the child.
    (output, err) = p.communicate()
    ## Wait for comand to terminate. Get return returncode ##
    p_status = p.wait()
    
    print("Output:\n%s" % (output.decode("utf-8")))
    print("Command exit status/return code: %d" % p_status)
    
    
if __name__ == "__main__":
    main()
