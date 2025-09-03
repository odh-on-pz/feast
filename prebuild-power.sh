#!/bin/bash
set -e

PYTHON_VERSION=3.11

echo "Installing build tools..."
dnf install -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-9.noarch.rpm
dnf install -y gcc-toolset-13 make cmake ninja-build libomp-devel clang \
               git python${PYTHON_VERSION} python${PYTHON_VERSION}-devel python${PYTHON_VERSION}-pip \
               openssl openssl-devel zlib-devel libuuid-devel 
source /opt/rh/gcc-toolset-13/enable

# Upgrade pip, build tools
python${PYTHON_VERSION} -m pip install build wheel setuptools ninja pybind11

mkdir -p /wheelhouse

# duckdb
echo "Building duckdb..."
git clone https://github.com/duckdb/duckdb.git
cd duckdb
git checkout v1.1.3

cd tools/pythonpkg
python${PYTHON_VERSION} -m build --wheel --no-isolation
cp dist/*.whl /wheelhouse/
cd ../../..

# grpcio
echo "Building grpcio..."
git clone https://github.com/grpc/grpc.git -b v1.62.3
cd grpc
git checkout v1.62.3
git submodule update --init --recursive
python${PYTHON_VERSION}  -m pip install -r requirements.txt
export CXX=/opt/rh/gcc-toolset-13/root/usr/bin/g++
export GRPC_PYTHON_BUILD_SYSTEM_OPENSSL=1
python${PYTHON_VERSION} -m build --wheel --no-isolation
cp dist/*.whl /wheelhouse/
cd ..

# pyarrow
echo "Building pyarrow..."
dnf install -y https://mirror.stream.centos.org/9-stream/BaseOS/ppc64le/os/Packages/centos-gpg-keys-9.0-24.el9.noarch.rpm \
https://mirror.stream.centos.org/9-stream/BaseOS/`arch`/os/Packages/centos-stream-repos-9.0-24.el9.noarch.rpm \
https://dl.fedoraproject.org/pub/epel/epel-release-latest-9.noarch.rpm
dnf config-manager --add-repo https://mirror.stream.centos.org/9-stream/BaseOS/ppc64le/os
dnf config-manager --add-repo https://mirror.stream.centos.org/9-stream/AppStream/ppc64le/os
dnf config-manager --set-enabled crb
dnf install -y boost1.78-devel.ppc64le gflags-devel rapidjson-devel.ppc64le re2-devel.ppc64le \
               utf8proc-devel.ppc64le gtest-devel gmock-devel snappy snappy-devel

git clone https://github.com/apache/arrow.git -b apache-arrow-17.0.0
cd arrow
git checkout apache-arrow-17.0.0
git submodule update --init --recursive

export ARROW_HOME=/usr/local
export LD_LIBRARY_PATH=$ARROW_HOME/lib64:$LD_LIBRARY_PATH
export PARQUET_TEST_DATA="${PWD}/cpp/submodules/parquet-testing/data"
export ARROW_TEST_DATA="${PWD}/testing/data"
export BUILD_TYPE=release
export BUNDLE_ARROW_CPP=1
export CMAKE_PREFIX_PATH=$ARROW_HOME

mkdir -p cpp/build && cd cpp/build
cmake -DCMAKE_BUILD_TYPE=release \
      -DCMAKE_INSTALL_PREFIX=$ARROW_HOME \
      -Dutf8proc_LIB=/usr/lib64/libutf8proc.so \
      -Dutf8proc_INCLUDE_DIR=/usr/include \
      -DARROW_PYTHON=ON \
      -DARROW_PARQUET=ON \
      -DARROW_BUILD_TESTS=ON \
      -DARROW_JEMALLOC=ON \
      ..
make -j$(nproc)
make install
python${PYTHON_VERSION} -m pip install --upgrade pip setuptools wheel numpy setuptools_scm
python${PYTHON_VERSION} -m pip install Cython==3.0.8
cd ../../python
python${PYTHON_VERSION} setup.py build_ext --build-type=$ARROW_BUILD_TYPE --bundle-arrow-cpp bdist_wheel
cp dist/*.whl /wheelhouse/
cd ../../..

# # milvus-lite
echo "Building milvus-lite..."
git clone --recursive https://github.com/milvus-io/milvus.git -b v2.3.0
cd milvus
# build steps

##### Steps ######
cd ..

