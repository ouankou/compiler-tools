#!/bin/bash

# LLVM 17+ requires GCC 12 or later to build.
# ./refresh.sh ${HOME}/Projects/opt-llvm-17

if [ -z "$1" ]; then
    exit 1
else
    LLVM=$1
fi

export LLVM_SRC=$LLVM/llvm_src
export LLVM_BUILD=$LLVM/llvm_build
export LLVM_PATH=/opt/llvm/llvm-install

cd $LLVM_SRC
git pull
cd $LLVM_BUILD
ninja -j18 -l18
sudo ninja install -j18
