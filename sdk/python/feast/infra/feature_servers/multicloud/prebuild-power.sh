#!/bin/bash
set -Eeuo pipefail
trap 'echo "[prebuild-power] failed at line $LINENO"; exit 1' ERR
shopt -s dotglob nullglob

PYTHON_VERSION=3.11
WORKDIR=$(pwd)
CMAKE_VERSION=3.30.5
CMAKE_REQUIRED_VERSION=3.30.5

: "${CFLAGS:=}"
: "${CXXFLAGS:=}"
: "${LDFLAGS:=}"
: "${LINKFLAGS:=}"
: "${CC_FOR_BUILD:=}"
: "${CXX_FOR_BUILD:=}"
: "${CMAKE_ARGS:=}"
: "${CPPFLAGS:=}"
: "${VIRTUAL_ENV_PATH:=}"
: "${CONDA_BUILD_CROSS_COMPILATION:=}"
: "${PREFIX:=}"
: "${FFLAGS:=}"

dnf install -y gcc-toolset-13 make cmake ninja-build libomp-devel \
               git python${PYTHON_VERSION} python${PYTHON_VERSION}-devel python${PYTHON_VERSION}-pip \
               openssl openssl-devel zlib-devel libuuid-devel lz4-devel libtool

# Enable GCC toolset
source /opt/rh/gcc-toolset-13/enable
export CXX=/opt/rh/gcc-toolset-13/root/usr/bin/g++

echo "Entering rapidson source directory..."
cd rapidjson
mkdir build && cd build
echo "Running cmake to configure the rapidjson build..."
cmake .. -DCMAKE_INSTALL_PREFIX=/usr/local
echo "Compiling the source code for rapidjson..."
make -j$(nproc)
echo "Installing rapidjson"
make install
