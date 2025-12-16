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

# GCC toolset 13 does not include libatomic, causing '-latomic not found' during linking.
# Symlink the system-provided libatomic.so.1 so the compiler can resolve it.
ln -s /usr/lib64/libatomic.so.1   /opt/rh/gcc-toolset-13/root/usr/lib/gcc/ppc64le-redhat-linux/13/libatomic.so

# Installing Python build dependencies
python${PYTHON_VERSION} -m pip install build wheel setuptools ninja pybind11 numpy==2.3.3 setuptools_scm Cython

# Directory to collect built wheels
mkdir -p /wheelhouse


#######################################################
# Build Pyarrow  (Python package)
#######################################################
echo "Entering Pyarrow source directory..."
export Boost_SOURCE_DIR=/tmp/boost-1.88.0
cd pyarrow
cd cpp
mkdir -p release && cd release
cmake -DCMAKE_BUILD_TYPE=Release \
      -DCMAKE_INSTALL_PREFIX=/usr/local \
      -DARROW_PYTHON=ON \
      -DARROW_PARQUET=ON \
      -DARROW_ORC=ON \
      -DARROW_FILESYSTEM=ON \
      -DARROW_FLIGHT=ON \
      -DARROW_FLIGHT_SQL=ON \
      -DARROW_WITH_LZ4=ON \
      -DARROW_WITH_ZSTD=ON \
      -DARROW_WITH_SNAPPY=ON \
      -DARROW_JSON=ON \
      -DARROW_CSV=ON \
      -DARROW_DATASET=ON \
      -DARROW_S3=ON \
      -DARROW_BUILD_TESTS=OFF \
      -DARROW_SUBSTRAIT=ON \
      -DProtobuf_SOURCE=BUNDLED \
      -DARROW_DEPENDENCY_SOURCE=BUNDLED \
    ..
make -j$(nproc)
make install
cd ../../python
export BUILD_TYPE=release
python${PYTHON_VERSION} setup.py build_ext --build-type=$BUILD_TYPE --bundle-arrow-cpp bdist_wheel
ls dist/*.whl >/dev/null
cp -v dist/*.whl /wheelhouse/
cd $WORKDIR

#######################################################

