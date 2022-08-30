#!/bin/bash

# Usage: source ./setup_gcc_env.sh /opt/gcc/gcc-12.x-install

if [ -z "$1" ]; then
    echo "Please provide a location of GCC installation, e.g. /opt/gcc/gcc-12.x-install"
    return -1 2>/dev/null
    exit -1
else
    GCC_PATH=$(cd $1; pwd)
fi

# Add GCC path
export PATH=${GCC_PATH}/bin:${PATH}
export LD_LIBRARY_PATH=${GCC_PATH}/lib64:${LD_LIBRARY_PATH}
