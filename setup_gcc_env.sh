#!/bin/bash

# Usage: source ./setup_gcc_env.sh /opt/gcc-12.x-instal

if [ -z "$1" ]; then
    echo "Please provide a location of GCC installation."
    return -1 2>/dev/null
    exit -1
else
    cd $1
    GCC_PATH=$(pwd)
    cd -
fi

# Add GCC path
export PATH=${GCC_PATH}/bin:${PATH}
export LD_LIBRARY_PATH=${GCC_PATH}/lib64:${LD_LIBRARY_PATH}
