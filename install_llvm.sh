#!/bin/bash

# LLVM 13+ requires GCC 11 or later to build.
# ./install_llvm.sh $HOME/Projects/llvm 15 86
# ./install_llvm.sh $HOME/Projects/llvm "" 86
# ./install_llvm.sh ${HOME}/Projects/opt-llvm-16 16 86

if [ -z "$1" ]; then
    LLVM=$HOME/llvm
else
    LLVM=$1
fi

if [ "$2" ]; then
    USE_GPU="-DLIBOMPTARGET_NVPTX_COMPUTE_CAPABILITIES=$3 -DLLVM_TARGETS_TO_BUILD='host;NVPTX' -DLIBOMPTARGET_ENABLE_DEBUG=ON -DLIBOMPTARGET_BUILD_DEVICERTL_BCLIB=ON"
fi

if [ -z "$3" ]; then
    LLVM_VERSION=main
else
    LLVM_VERSION=release/$2.x
fi

if [ -z "$4" ]; then
    BUILD_VERSION=RELEASE
else
    BUILD_VERSION=DEBUG
fi

export LLVM_SRC=$LLVM/llvm_src
export LLVM_BUILD=$LLVM/llvm_build
export LLVM_PATH=/opt/llvm/llvm-install

mkdir -p $LLVM_SRC
mkdir -p $LLVM_BUILD
sudo mkdir -p $LLVM_PATH

cd $LLVM_SRC
git clone https://github.com/llvm/llvm-project .
cd $LLVM_BUILD
CC=gcc CXX=g++ cmake -G Ninja -DLLVM_USE_LINKER=gold -DLLVM_ENABLE_RTTI=ON -DCMAKE_BUILD_TYPE=$BUILD_VERSION -DCMAKE_INSTALL_PREFIX=$LLVM_PATH -DLLVM_ENABLE_PROJECTS="clang;clang-tools-extra;compiler-rt;mlir;lldb" -DLLVM_ENABLE_RUNTIMES="libcxx;libcxxabi;openmp" -DOPENMP_ENABLE_LIBOMP_PROFILING=ON $USE_GPU -DLLVM_BUILD_EXAMPLES=ON $LLVM_SRC/llvm
ninja -j18 -l18
sudo ninja install -j18
