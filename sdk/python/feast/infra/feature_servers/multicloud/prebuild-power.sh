#!/bin/bash
set -Eeuo pipefail
trap 'echo "[prebuild-power] failed at line $LINENO"; exit 1' ERR
shopt -s dotglob nullglob

PYTHON_VERSION=3.11
WORKDIR=$(pwd)
CMAKE_VERSION=3.30.5
CMAKE_REQUIRED_VERSION=3.30.5

dnf install -y gcc-toolset-13 make cmake ninja-build libomp-devel \
               git python${PYTHON_VERSION} python${PYTHON_VERSION}-devel python${PYTHON_VERSION}-pip \
               openssl openssl-devel zlib-devel libuuid-devel 

# Enable GCC toolset
source /opt/rh/gcc-toolset-13/enable
export CXX=/opt/rh/gcc-toolset-13/root/usr/bin/g++

# Ensure CXXFLAGS and LINKFLAGS are initialized
: "${CMAKE_ARGS:=""}"
: "${CXXFLAGS:=""}"
: "${CFLAGS:=""}"
: "${LINKFLAGS:=""}"

# Installing Python build dependencies
python${PYTHON_VERSION} -m pip install build wheel setuptools ninja pybind11 numpy setuptools_scm Cython==3.0.8

# Directory to collect built wheels
mkdir -p /wheelhouse

#######################################################
# Build DuckDB (Python package)
#######################################################
# echo "Entering DuckDB source directory..."
# cd /tmp/duckdb-1.1.3/tools/pythonpkg
# export SETUPTOOLS_SCM_PRETEND_VERSION=1.1.3
# python${PYTHON_VERSION} -m build --wheel --no-isolation
# ls dist/*.whl >/dev/null
# cp -v dist/*.whl /wheelhouse/
# cd $WORKDIR

#######################################################
# Build gRPC  (Python package)
#######################################################
# echo "Building grpcio..."
# export GRPC_PYTHON_BUILD_SYSTEM_OPENSSL=1
# pip install grpcio==1.62.3

#######################################################
# Build Pyarrow  (Python package)
#######################################################
# echo "Entering Pyarrow source directory..."
# cd /tmp/arrow-apache-arrow-17.0.0
# cd cpp
# mkdir -p release && cd release
# cmake -DCMAKE_BUILD_TYPE=Release \
#       -DCMAKE_INSTALL_PREFIX=/usr/local \
#       -DARROW_PYTHON=ON \
#       -DARROW_PARQUET=ON \
#       -DARROW_ORC=ON \
#       -DARROW_FILESYSTEM=ON \
#       -DARROW_WITH_LZ4=ON \
#       -DARROW_WITH_ZSTD=ON \
#       -DARROW_WITH_SNAPPY=ON \
#       -DARROW_JSON=ON \
#       -DARROW_CSV=ON \
#       -DARROW_DATASET=ON \
#       -DARROW_S3=ON \
#       -DARROW_SUBSTRAIT=ON \
#       -DProtobuf_SOURCE=BUNDLED \
#       -DARROW_DEPENDENCY_SOURCE=BUNDLED \
#     ..
# make -j$(nproc)
# make install
# cd ../../python
# export BUILD_TYPE=release
# python${PYTHON_VERSION} setup.py build_ext --build-type=$BUILD_TYPE --bundle-arrow-cpp bdist_wheel
# ls dist/*.whl >/dev/null
# cp -v dist/*.whl /wheelhouse/
# cd ../../..

#######################################################
# Build Milvus-Lite  (Python package)
#######################################################
echo "Building milvus-lite..."
dnf remove -y gcc-toolset-13

dnf install -y perl ncurses-devel wget openblas-devel cargo gcc gcc-c++ libstdc++-static which libaio \
               libtool m4 autoconf automake zlib-devel libffi-devel scl-utils xz

export CC=gcc
export CXX=g++
export CXXFLAGS="-std=c++17"

python${PYTHON_VERSION} -m pip install wheel conan==1.64.1 setuptools==70.0.0

# echo "installing texinfo"
# wget https://ftp.gnu.org/gnu/texinfo/texinfo-7.1.tar.xz
# tar -xf texinfo-7.1.tar.xz
# cd texinfo-7.1
# ./configure
# make -j2
# make install
# cd ..

# echo "installing rust 1.73"
# curl https://sh.rustup.rs -sSf | sh -s -- --default-toolchain=1.73 -y
# source $HOME/.cargo/env
# rustc --version

# echo "installing cmake"
# # Install CMake
# mkdir -p "${WORKDIR}/workspace"
# cd "${WORKDIR}/workspace"
# wget -c https://github.com/Kitware/CMake/releases/download/v${CMAKE_VERSION}/cmake-${CMAKE_VERSION}.tar.gz
# tar -zxvf cmake-${CMAKE_VERSION}.tar.gz
# rm -rf cmake-${CMAKE_VERSION}.tar.gz
# cd cmake-${CMAKE_VERSION}
# ./bootstrap --prefix=/usr/local/cmake --parallel=2 -- -DBUILD_TESTING:BOOL=OFF -DCMAKE_BUILD_TYPE:STRING=Release -DCMAKE_USE_OPENSSL:BOOL=ON
# make install -j2
# export PATH=/usr/local/cmake/bin:$PATH
# cmake --version
# cd ..

# cd $WORKDIR
git clone https://github.com/milvus-io/milvus-lite
cd milvus-lite/python
git checkout v2.4.12
git submodule update --init --recursive
python${PYTHON_VERSION} -m pip install -v -e .

# create_cmake_conanfile()
# {
#     touch /usr/local/cmake/conanfile.py
#     cat <<EOT >> /usr/local/cmake/conanfile.py
# from conans import ConanFile, tools
# class CmakeConan(ConanFile):
#   name = "cmake"
#   package_type = "application"
#   version = "${CMAKE_REQUIRED_VERSION}"
#   description = "CMake, the cross-platform, open-source build system."
#   homepage = "https://github.com/Kitware/CMake"
#   license = "BSD-3-Clause"
#   topics = ("build", "installer")
#   settings = "os", "arch"
#   def package(self):
#     self.copy("*")
#   def package_info(self):
#     self.cpp_info.libs = tools.collect_libs(self)
# EOT
# }

# #build the package
# pushd /usr/local/cmake
# create_cmake_conanfile
# conan export-pkg . cmake/${CMAKE_REQUIRED_VERSION}@ -s os="Linux" -s arch="ppc64le" -f
# conan profile update settings.compiler.libcxx=libstdc++11 default
# popd
# export VCPKG_FORCE_SYSTEM_BINARIES=1
# mkdir -p $HOME/.cargo/bin/

# python${PYTHON_VERSION} -m build --wheel --no-isolation

# ls dist/*.whl >/dev/null
# cp -v dist/*.whl /wheelhouse/


