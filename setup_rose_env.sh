#!/bin/bash

# source ./setup_rose_env.sh $HOME/Projects/rose

if [ -z "$1" ]; then
    echo "Please provide a location of ROSE installation, e.g. $HOME/Projects/rose"
    return -1 2>/dev/null
    exit -1
else
    export ROSE_ROOT=$(cd $1; pwd)
fi

export LD_LIBRARY_PATH=$ROSE_ROOT/install/lib:$LD_LIBRARY_PATH
export PATH=$ROSE_ROOT/install/bin:$PATH

# command to build ROSE
# CC=gcc-9 CXX=g++-9 FC=gfortran-9 ../src/configure --prefix=$ROSE_ROOT/install --with-boost=/usr --with-boost-libdir=/usr/lib/x86_64-linux-gnu --enable-languages=c,c++,fortran --disable-tests-directory --disable-tutorial-directory --with-gomp_omp_runtime_library=/usr/lib/gcc/x86_64-linux-gnu/9
