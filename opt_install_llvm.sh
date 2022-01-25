#!/bin/bash

# LLVM 13+ requires GCC 11 or later to build.
# ./opt_install_llvm.sh /scratch/awang15/llvm/opt-llvm14-gpu 14 70

if [ -z "$1" ]; then
    LLVM=$HOME/llvm
else
    LLVM=$1
fi

if [ -z "$2" ]; then
    LLVM_VERSION=10
else
    LLVM_VERSION=$2
fi

if [ "$3" ]; then
    USE_GPU="-DCLANG_OPENMP_NVPTX_DEFAULT_ARCH=sm_$3 -DLIBOMPTARGET_NVPTX_COMPUTE_CAPABILITIES=$3"
fi

export LLVM_SRC=$LLVM/llvm_src
export LLVM_BUILD=$LLVM/llvm_build
export LLVM_PATH=/opt/llvm/llvm-$LLVM_VERSION.x-install

mkdir -p $LLVM_SRC
mkdir -p $LLVM_BUILD
sudo mkdir -p $LLVM_PATH

cd $LLVM_SRC
git clone https://github.com/llvm/llvm-project .
#git clone -b release/$LLVM_VERSION.x https://github.com/llvm/llvm-project .
cd $LLVM_BUILD
CC=gcc-11 CXX=g++-11 cmake -G Ninja -DLLVM_USE_LINKER=gold -DLLVM_ENABLE_RTTI=ON -DCMAKE_BUILD_TYPE=DEBUG -DCMAKE_INSTALL_PREFIX=$LLVM_PATH -DLLVM_ENABLE_PROJECTS="mlir;clang;clang-tools-extra;compiler-rt;openmp;libcxx;libcxxabi;lldb" -DLLVM_TARGETS_TO_BUILD="host;NVPTX" $USE_GPU -DLLVM_BUILD_EXAMPLES=ON -DLLVM_ENABLE_ASSERTIONS=OFF $LLVM_SRC/llvm

ninja -j6 -l6
sudo ninja install -j6

CC=gcc-11 CXX=g++-11 cmake -G Ninja -DLLVM_USE_LINKER=gold -DLLVM_ENABLE_RTTI=ON -DCMAKE_BUILD_TYPE=DEBUG -DCMAKE_INSTALL_PREFIX=$LLVM_PATH -DLLVM_ENABLE_PROJECTS="mlir;clang;clang-tools-extra;compiler-rt;openmp;libcxx;libcxxabi;lldb" -DLLVM_TARGETS_TO_BUILD="host;NVPTX" $USE_GPU -DLIBOMPTARGET_NVPTX_ENABLE_BCLIB=ON -DLIBOMPTARGET_NVPTX_CUDA_COMPILER=$LLVM_PATH/bin/clang -DLLVM_BUILD_EXAMPLES=ON -DLLVM_ENABLE_ASSERTIONS=OFF $LLVM_SRC/llvm
ninja -j6 -l6
sudo ninja install -j6

export PATH=$LLVM_PATH/bin:$PATH
export LD_LIBRARY_PATH=$LLVM_PATH/libexec:$LD_LIBRARY_PATH
export LD_LIBRARY_PATH=$LLVM_PATH/lib:$LD_LIBRARY_PATH
export LIBRARY_PATH=$LLVM_PATH/libexec:$LIBRARY_PATH
export LIBRARY_PATH=$LLVM_PATH/lib:$LIBRARY_PATH
export MANPATH=$LLVM_PATH/share/man:$MANPATH
export C_INCLUDE_PATH=$LLVM_PATH/include:$C_INCLUDE_PATH
export CPLUS_INCLUDE_PATH=$LLVM_PATH/include:CPLUS_INCLUDE_PATH

