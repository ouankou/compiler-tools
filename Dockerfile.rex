# Environment for REX compiler development.

# Pull base image.
FROM ubuntu:22.04

RUN --mount=type=secret,id=token token=$(cat /run/secrets/token) && [ -n "$token" ]

# Install packages.
RUN \
    apt-get update && \
    apt-get install -y \
        apt-utils \
        dialog \
        software-properties-common && \
    apt-get install -y openjdk-8-jdk && \
    apt-get install -y \ 
        antlr4 \
        automake \
        autotools-dev \
        bison \
        build-essential \
        cmake \
        curl \
        flex \
        g++-9 \
        gdb \
        gfortran-9 \
        ghostscript \
        git \
        graphviz \
        libantlr4-runtime-dev \
        libboost-all-dev \
        libtool \
        python3-dev \
        vim \
        wget && \
  rm -rf /var/lib/apt/lists/* && \
  rm -rf /var/cache/*

# Setup environment
ENV REX_SRC /opt/rex_src
ENV REX_PATH /opt/rex
ENV REX_BUILD /opt/rex_build
ENV PATH $REX_PATH/bin:$PATH
ENV LD_LIBRARY_PATH $REX_PATH/lib:$LD_LIBRARY_PATH
ENV LIBRARY_PATH $REX_PATH/lib:$LIBRARY_PATH

# Define commonly used JAVA_HOME variable
ENV JAVA_HOME /usr/lib/jvm/java-8-openjdk-amd64
ENV LD_LIBRARY_PATH $JAVA_HOME/jre/lib/amd64/server:/usr/lib/x86_64-linux-gnu

# Username doesn't need to be defined. The host user has to be passed into Docker for correct file permissions.
RUN --mount=type=secret,id=token \
    cd /opt && \
    mkdir -p $REX_PATH && \
    mkdir -p $REX_BUILD && \
    git clone -b dev https://github.com/passlab/rexompiler.git $REX_SRC && \
    cd $REX_SRC && \
    git config submodule.src/frontend/CxxFrontend/EDG.url https://ouankou:$(cat /run/secrets/token)@github.com/passlab/EDG.git && \
    git submodule update --init && \
    ./build && \
    cd $REX_BUILD && \
    CC=gcc-9 CXX=g++-9 FC=gfortran-9 $REX_SRC/configure --prefix=$REX_PATH --with-boost=/usr --with-boost-libdir=/usr/lib/x86_64-linux-gnu --enable-languages=c,c++,fortran --with-gomp_omp_runtime_library=/usr/lib/gcc/x86_64-linux-gnu/9 && \
    cd $REX_BUILD && \
    make install-rex -j6 && \
    make check-rex && \
    cd /opt && \
    rm -rf $REX_SRC $REX_BUILD

# Define default command.
CMD ["bash"]
