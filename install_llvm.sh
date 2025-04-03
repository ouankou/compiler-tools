#!/bin/bash

# LLVM 17+ requires GCC 12 or later to build.
# ./install_llvm.sh $HOME/Projects/llvm 20 1
# ./install_llvm.sh $HOME/Projects/llvm "" 1
# CC=gcc-12 CXX=g++-12 ./install_llvm.sh ${HOME}/Projects/llvm-20 20 1

NUM_THREADS=$(nproc)
TRIPLE=$(gcc -dumpmachine)

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

LLVM_RUNTIMES="compiler-rt;libcxx;libcxxabi;openmp;libunwind"
if [ -z "$3" ]; then
    USE_GPU=""
else
    USE_GPU="-DLLVM_TARGETS_TO_BUILD='host;AMDGPU;NVPTX' -DLIBOMPTARGET_ENABLE_DEBUG=ON -DLIBOMPTARGET_BUILD_DEVICERTL_BCLIB=ON"
    LLVM_RUNTIMES="$LLVM_RUNTIMES;offload"
fi

if [ -z "$4" ]; then
    BUILD_VERSION=RELEASE
else
    BUILD_VERSION=DEBUG
fi

export LLVM_SRC=$LLVM/llvm_src
export LLVM_BUILD=$LLVM/llvm_build
export LLVM_PATH=$LLVM/llvm_install

mkdir -p $LLVM_SRC
mkdir -p $LLVM_BUILD
mkdir -p $LLVM_PATH

cd $LLVM_SRC
if [ -d llvm ]; then
    git pull
else
    git clone $LLVM_VERSION https://github.com/llvm/llvm-project .
fi

cd $LLVM_BUILD
if [ ! -d llvm ]; then
    cmake -G Ninja \
      -DCMAKE_BUILD_TYPE=$BUILD_VERSION \
      -DCMAKE_CXX_COMPILER_TARGET=$TRIPLE \
      -DCMAKE_C_COMPILER_TARGET=$TRIPLE \
      -DCMAKE_INSTALL_PREFIX=$LLVM_PATH \
      -DLLVM_BINUTILS_INCDIR=/usr/include \
      -DLLVM_BUILD_DOCS=OFF \
      -DLLVM_DEFAULT_TARGET_TRIPLE=$TRIPLE \
      -DLLVM_ENABLE_PROJECTS="clang;clang-tools-extra;flang;lld;lldb;mlir" \
      -DLLVM_ENABLE_RUNTIMES="$LLVM_RUNTIMES" \
      -DLLVM_USE_LINKER=mold \
      -DOPENMP_ENABLE_LIBOMP_PROFILING=ON \
      $USE_GPU \
      $LLVM_SRC/llvm
fi

ninja -j$NUM_THREADS -l$NUM_THREADS
ninja install -j$NUM_THREADS
