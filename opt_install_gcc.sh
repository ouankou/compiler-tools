#!/bin/bash

#
# Build GCC with support for offloading to NVIDIA GPUs.
#

BASE_DIR=/scratch/awang15/opt-gcc-11

work_dir=${BASE_DIR}/offload/wrk
install_dir=/opt/gcc/gcc-11.x-install
sudo mkdir -p ${install_dir}

# Location of the installed CUDA toolkit
#cuda=/usr/local/cuda
cuda=/opt/nvidia/hpc_sdk/Linux_x86_64/22.1/cuda/11.5

# Build assembler and linking tools
mkdir -p $work_dir
cd $work_dir
git clone https://github.com/MentorEmbedded/nvptx-tools
cd nvptx-tools
./configure \
    --with-cuda-driver-include=$cuda/include \
    --with-cuda-driver-lib=$cuda/lib64 \
    --prefix=$install_dir
make || exit 1
sudo make install || exit 1
cd ..

# Set up the GCC source tree
git clone git://sourceware.org/git/newlib-cygwin.git nvptx-newlib
git clone --branch releases/gcc-11 git://gcc.gnu.org/git/gcc.git gcc
cd gcc
contrib/download_prerequisites
ln -s ../nvptx-newlib/newlib newlib
cd ..
target=$(gcc/config.guess)

# Build nvptx GCC
mkdir build-nvptx-gcc
cd build-nvptx-gcc
../gcc/configure \
    --target=nvptx-none --with-build-time-tools=$install_dir/nvptx-none/bin \
    --enable-as-accelerator-for=$target \
    --disable-sjlj-exceptions \
    --enable-newlib-io-long-long \
    --enable-languages="c,c++,fortran,lto" \
    --prefix=$install_dir
make -j`nproc` || exit 1
sudo make install || exit 1
cd ..

# Build host GCC
mkdir build-host-gcc
cd  build-host-gcc
../gcc/configure \
    --enable-offload-targets=nvptx-none \
    --with-cuda-driver-include=$cuda/include \
    --with-cuda-driver-lib=$cuda/lib64 \
    --disable-bootstrap \
    --disable-multilib \
    --enable-languages="c,c++,fortran,lto" \
    --prefix=$install_dir
make -j`nproc` || exit 1
sudo make install || exit 1
cd ..
