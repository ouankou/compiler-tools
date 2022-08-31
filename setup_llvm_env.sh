#!/bin/bash

# source ./setup_llvm_env.sh /opt/llvm/llvm-15.x-install

if [ -z "$1" ]; then
    echo "Please provide a location of LLVM installation, e.g. /opt/llvm/llvm-15.x-install"
    return -1 2>/dev/null
    exit -1
else
    LLVM_PATH=$(cd $1; pwd)
fi

export PATH=$LLVM_PATH/bin:$PATH
export LD_LIBRARY_PATH=$LLVM_PATH/libexec:$LD_LIBRARY_PATH
export LD_LIBRARY_PATH=$LLVM_PATH/lib:$LD_LIBRARY_PATH
export LIBRARY_PATH=$LLVM_PATH/libexec:$LIBRARY_PATH
export LIBRARY_PATH=$LLVM_PATH/lib:$LIBRARY_PATH
export MANPATH=$LLVM_PATH/share/man:$MANPATH
export C_INCLUDE_PATH=$LLVM_PATH/include:$C_INCLUDE_PATH
export CPLUS_INCLUDE_PATH=$LLVM_PATH/include:CPLUS_INCLUDE_PATH
