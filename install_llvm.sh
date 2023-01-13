#!/bin/bash

# LLVM 13+ requires GCC 11 or later to build.
# ./install_llvm.sh $HOME/Projects/llvm 15 86
# ./install_llvm.sh $HOME/Projects/llvm "" 86

if [ -z "$1" ]; then
    LLVM=$HOME/llvm
else
    LLVM=$1
fi

if [ -z "$2" ]; then
    LLVM_VERSION=main
else
    LLVM_VERSION=release/$2.x
fi

if [ "$3" ]; then
    USE_GPU="-DCLANG_OPENMP_NVPTX_DEFAULT_ARCH=sm_$3 -DLIBOMPTARGET_NVPTX_COMPUTE_CAPABILITIES=$3 -DLLVM_TARGETS_TO_BUILD='host;NVPTX' -DLIBOMPTARGET_ENABLE_DEBUG=ON -DLIBOMPTARGET_BUILD_DEVICERTL_BCLIB=ON"
fi

if [ -z "$4" ]; then
    BUILD_VERSION=RELEASE
else
    BUILD_VERSION=DEBUG
fi

export LLVM_SRC=$LLVM/llvm_src
export LLVM_PATH=$LLVM/llvm_install
export LLVM_BUILD=$LLVM/llvm_build

mkdir -p $LLVM_SRC
mkdir -p $LLVM_PATH
mkdir -p $LLVM_BUILD
cd $LLVM_SRC
git clone -b $LLVM_VERSION https://github.com/llvm/llvm-project .
cd $LLVM_BUILD
CC=gcc CXX=g++ cmake -G Ninja -DLLVM_USE_LINKER=gold -DLLVM_ENABLE_RTTI=ON -DCMAKE_BUILD_TYPE=$BUILD_VERSION -DCMAKE_INSTALL_PREFIX=$LLVM_PATH -DLLVM_ENABLE_PROJECTS="clang;clang-tools-extra;compiler-rt;mlir;lldb;openmp" -DLLVM_ENABLE_RUNTIMES="libcxx;libcxxabi" -DOPENMP_ENABLE_LIBOMP_PROFILING=ON $USE_GPU -DLLVM_BUILD_EXAMPLES=ON $LLVM_SRC/llvm
ninja -j18 -l18
ninja install -j18

export PATH=$LLVM_PATH/bin:$PATH
export LD_LIBRARY_PATH=$LLVM_PATH/libexec:$LD_LIBRARY_PATH
export LD_LIBRARY_PATH=$LLVM_PATH/lib:$LD_LIBRARY_PATH
export LIBRARY_PATH=$LLVM_PATH/libexec:$LIBRARY_PATH
export LIBRARY_PATH=$LLVM_PATH/lib:$LIBRARY_PATH
export MANPATH=$LLVM_PATH/share/man:$MANPATH
export C_INCLUDE_PATH=$LLVM_PATH/include:$C_INCLUDE_PATH
export CPLUS_INCLUDE_PATH=$LLVM_PATH/include:CPLUS_INCLUDE_PATH

