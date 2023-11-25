#!/bin/bash

# LLVM 17+ requires GCC 12 or later to build.
# ./install_llvm.sh $HOME/Projects/llvm 17 86
# ./install_llvm.sh $HOME/Projects/llvm "" 86
# CC=gcc-12 CXX=g++-12 ./install_llvm.sh ${HOME}/Projects/opt-llvm-17 17 86

if [ -z "$1" ]; then
    LLVM=$HOME/llvm
else
    LLVM=$1
fi

if [ -z "$2" ]; then
    LLVM_VERSION=""
else
    LLVM_VERSION="-b release/$2.x"
fi

if [ "$3" ]; then
    USE_GPU="-DLLVM_TARGETS_TO_BUILD='host;NVPTX' -DLIBOMPTARGET_ENABLE_DEBUG=ON -DLIBOMPTARGET_BUILD_DEVICERTL_BCLIB=ON"
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
git clone $LLVM_VERSION https://github.com/llvm/llvm-project .
cd $LLVM_BUILD
cmake -G Ninja -DLLVM_USE_LINKER=gold -DLLVM_ENABLE_RTTI=ON -DCMAKE_BUILD_TYPE=$BUILD_VERSION -DCMAKE_INSTALL_PREFIX=$LLVM_PATH -DLLVM_ENABLE_PROJECTS="clang;clang-tools-extra;compiler-rt;mlir;lldb" -DLLVM_ENABLE_RUNTIMES="libcxx;libcxxabi;openmp" -DOPENMP_ENABLE_LIBOMP_PROFILING=ON $USE_GPU -DLLVM_BUILD_EXAMPLES=ON $LLVM_SRC/llvm
ninja -j18 -l18
sudo ninja install -j18
