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

dnf install -y gcc-toolset-13 make cmake ninja-build libomp-devel \
               git python${PYTHON_VERSION} python${PYTHON_VERSION}-devel python${PYTHON_VERSION}-pip \
               openssl openssl-devel zlib-devel libuuid-devel lz4-devel

# Enable GCC toolset
source /opt/rh/gcc-toolset-13/enable
export CXX=/opt/rh/gcc-toolset-13/root/usr/bin/g++

# GCC toolset 13 does not include libatomic, causing '-latomic not found' during linking.
# Symlink the system-provided libatomic.so.1 so the compiler can resolve it.
ln -sf /usr/lib64/libatomic.so.1 /opt/rh/gcc-toolset-13/root/usr/lib/gcc/ppc64le-redhat-linux/13/libatomic.so

# Installing Python build dependencies
python${PYTHON_VERSION} -m pip install build wheel setuptools ninja pybind11 setuptools_scm Cython

# Directory to collect built wheels
mkdir -p /wheelhouse

############### Numpy Installing ###########################
echo "Installing numpy ..."
cd numpy
python${PYTHON_VERSION} -m pip install .
cd $WORKDIR

################## flex installing ############################
echo "Entering flex source directory..."
cd /tmp/flex-2.6.4
echo "Configuring flex installation..."
./configure --prefix=/usr/local
echo "Compiling the source code for flex..."
make -j$(nproc)
echo "Installing flex..."
make install
cd $WORKDIR

#################### bison installing #############################
echo "Entering Bison source directory..."
cd /tmp/bison-3.8.2
echo "Configuring bison installation..."
./configure --prefix=/usr/local
echo "Compiling the source code bison..."
make -j$(nproc)
echo "Installing bison..."
make install
cd $WORKDIR

##################### gflags installing ##############################
echo "Entering gflags source directory..."
cd gflags
mkdir build && cd build
echo "Running cmake to configure the gflags build..."
cmake ..
echo "Compiling the source code gflags..."
make -j$(nproc)
echo "Installing gflags..."
make install
cd $WORKDIR


##################### Installing c-ares ##########################
echo "Entering c-ares source directory..."
cd c-ares
target_platform=$(uname)-$(uname -m)
AR=$(which ar)
PKG_NAME=c-ares

mkdir -p c_ares_prefix
export C_ARES_PREFIX=$(pwd)/c_ares_prefix

echo "Building ${PKG_NAME}."

# Isolate the build.
mkdir build && cd build

if [[ "$PKG_NAME" == *static ]]; then
  CARES_STATIC=ON
  CARES_SHARED=OFF
else
  CARES_STATIC=OFF
  CARES_SHARED=ON
fi

if [[ "${target_platform}" == Linux-* ]]; then
  CMAKE_ARGS="${CMAKE_ARGS} -DCMAKE_AR=${AR}"
fi

# Generate the build files.
echo "Generating the build files..."
cmake ${CMAKE_ARGS} .. \
      -DCMAKE_BUILD_TYPE=Release \
      -DCMAKE_INSTALL_PREFIX="$C_ARES_PREFIX" \
      -DCARES_STATIC=${CARES_STATIC} \
      -DCARES_SHARED=${CARES_SHARED} \
      -DCARES_INSTALL=ON \
      -DCMAKE_INSTALL_LIBDIR=lib \
      -GNinja
      #${SRC_DIR}

# Build.
echo "Building c-areas..."
ninja || exit 1

# Installing
echo "Installing c-areas..."
ninja install || exit 1
cd $WORKDIR


################## rapidjson installing ########################
# echo "Entering rapidson source directory..."
# cd rapidjson
# mkdir build && cd build
# echo "Running cmake to configure the rapidjson build..."
# cmake .. -DCMAKE_INSTALL_PREFIX=/usr/local
# echo "Compiling the source code for rapidjson..."
# make -j$(nproc)
# echo "Installing rapidjson"
# make install
# cd $WORKDIR

################### xsimd installing ############################
echo "Entering xsimd source directory..."
cd xsimd
mkdir build && cd build
echo "Running cmake to configure the build for xsimd.."
cmake .. -DCMAKE_INSTALL_PREFIX=/usr/local
echo "Compiling the source code for xsimd..."
make -j$(nproc)
echo "Installing xsimd..."
make install
cd $WORKDIR

#################### snappy installing ###########################
echo "Entering snappy source directory..."
cd snappy
mkdir -p local/snappy
export SNAPPY_PREFIX=$(pwd)/local/snappy
mkdir build
cd build
echo "Running cmake to configure the build for snappy..."
cmake -DCMAKE_INSTALL_PREFIX=$SNAPPY_PREFIX \
      -DBUILD_SHARED_LIBS=ON \
      -DCMAKE_INSTALL_LIBDIR=lib \
      ..
echo "Compiling the source code for snappy..."
make -j$(nproc)
echo "Installing snappy..."
make install
cd ..
cd $WORKDIR

#################### libzstd installing ##########################
echo "Entering libzstd source directory..."
cd zstd
echo "Compiling the source code for libzstd..."
make
echo "Installing libzstd..."
make install
export ZSTD_HOME=/usr/local
export CMAKE_PREFIX_PATH=$ZSTD_HOME
export LD_LIBRARY_PATH=$ZSTD_HOME/lib64:$LD_LIBRARY_PATH
cd $WORKDIR


#################### re2 installing ###############################
echo "Entering re2 source directory..."
cd re2
mkdir re2-prefix
export RE2_PREFIX=$(pwd)/re2-prefix
export CPU_COUNT=`nproc`

mkdir build-cmake
pushd build-cmake

echo "Running cmake to configure the build for re2..."
cmake ${CMAKE_ARGS} -GNinja \
  -DCMAKE_PREFIX_PATH=$RE2_PREFIX \
  -DCMAKE_INSTALL_PREFIX="${RE2_PREFIX}" \
  -DCMAKE_INSTALL_LIBDIR=lib \
  -DENABLE_TESTING=OFF \
  -DCMAKE_BUILD_TYPE=Release \
  -DBUILD_SHARED_LIBS=ON \
  ..
echo "Installing re2..."
  ninja -v install
  popd
echo "Running make shared-install......"
make -j "${CPU_COUNT}" prefix=${RE2_PREFIX} shared-install
cd $WORKDIR


#################### utf8proc installing #########################
echo "Entering utf8proc source directory..."
cd utf8proc
mkdir utf8proc_prefix
export UTF8PROC_PREFIX=$(pwd)/utf8proc_prefix

# Create build directory
mkdir build
cd build
echo "Running cmake to configure the build for utf8proc..."
# Run cmake to configure the build
cmake -G "Unix Makefiles" \
  -DCMAKE_BUILD_TYPE="Release" \
  -DCMAKE_INSTALL_PREFIX="${UTF8PROC_PREFIX}" \
  -DCMAKE_POSITION_INDEPENDENT_CODE=1 \
  -DBUILD_SHARED_LIBS=1 \
  ..
echo  "Build and install utf8proc"
cmake --build .

echo "Installing utf8proc ..."
cmake --build . --target install
cd $WORKDIR

################## abseil_cpp cloning #########################

################## libprotobuf installing #####################
export C_COMPILER=$(which gcc)
export CXX_COMPILER=$(which g++)

echo "Entering protobuf source directory..."

#Build libprotobuf
cd protobuf

LIBPROTO_DIR=$(pwd)
mkdir -p $LIBPROTO_DIR/local/libprotobuf
LIBPROTO_INSTALL=$LIBPROTO_DIR/local/libprotobuf

rm -rf ./third_party/googletest | true
rm -rf ./third_party/abseil-cpp | true

cp -r $WORKDIR/abseil-cpp ./third_party/

mkdir build
cd build
echo "Running cmake to configure the build for libprotobuf..."
cmake -G "Ninja" \
   ${CMAKE_ARGS} \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_CXX_STANDARD=17 \
    -DCMAKE_C_COMPILER=$C_COMPILER \
    -DCMAKE_CXX_COMPILER=$CXX_COMPILER \
    -DCMAKE_INSTALL_PREFIX=$LIBPROTO_INSTALL \
    -Dprotobuf_BUILD_TESTS=OFF \
    -Dprotobuf_BUILD_LIBUPB=OFF \
    -Dprotobuf_BUILD_SHARED_LIBS=ON \
    -Dprotobuf_ABSL_PROVIDER="module" \
    -Dprotobuf_JSONCPP_PROVIDER="package" \
    -Dprotobuf_USE_EXTERNAL_GTEST=OFF \
    ..
echo  "Building libprotobuf..."
cmake --build . --verbose
echo  "Installing libprotobuf..."
cmake --install .
cd $WORKDIR

################### orc installing ###############################
echo "Entering orc source directory..."
cd orc
patch -p1 < /tmp/orc.patch
mkdir orc_prefix
export ORC_PREFIX=$(pwd)/orc_prefix

mkdir -p build
cd build

export PROTOBUF_PREFIX=$LIBPROTO_INSTALL
export CMAKE_PREFIX_PATH=$LIBPROTO_INSTALL
export LD_LIBRARY_PATH=$LIBPROTO_INSTALL/lib64

export CC=$(which gcc)
export CXX=$(which g++)
export GCC=$CC
export GXX=$CXX

export HOST=$(uname)-$(uname -m)
export HOST=$(uname)-$(uname -m)

CPPFLAGS="${CPPFLAGS} -Wl,-rpath,$VIRTUAL_ENV_PATH/**/lib"


declare -a _CMAKE_EXTRA_CONFIG
if [[ "$CONDA_BUILD_CROSS_COMPILATION" == 1 ]]; then
    _CMAKE_EXTRA_CONFIG+=(-DHAS_PRE_1970_EXITCODE=0)
    _CMAKE_EXTRA_CONFIG+=(-DHAS_PRE_1970_EXITCODE__TRYRUN_OUTPUT=)
    _CMAKE_EXTRA_CONFIG+=(-DHAS_POST_2038_EXITCODE=0)
    _CMAKE_EXTRA_CONFIG+=(-DHAS_POST_2038_EXITCODE__TRYRUN_OUTPUT=)
fi
if [[ ${HOST} =~ .*darwin.* ]]; then
    _CMAKE_EXTRA_CONFIG+=(-DCMAKE_AR=${AR})
    _CMAKE_EXTRA_CONFIG+=(-DCMAKE_RANLIB=${RANLIB})
    _CMAKE_EXTRA_CONFIG+=(-DCMAKE_LINKER=${LD})
fi
if [[ ${HOST} =~ .*Linux.* ]]; then
    CXXFLAGS="${CXXFLAGS//-std=c++17/-std=c++11}"
    LIBPTHREAD=$(find ${PREFIX} -name "libpthread.so")
    _CMAKE_EXTRA_CONFIG+=(-DPTHREAD_LIBRARY=${LIBPTHREAD})
fi

CPPFLAGS="${CPPFLAGS} -Wl,-rpath,$VIRTUAL_ENV_PATH/**/lib"
echo "Running cmake to configure the build for orc..."
cmake ${CMAKE_ARGS} \
    -DCMAKE_PREFIX_PATH=$ORC_PREFIX \
    -DCMAKE_BUILD_TYPE=Release \
    -DBUILD_SHARED_LIBS=ON \
    -DBUILD_JAVA=False \
    -DLZ4_HOME=/usr \
    -DZLIB_HOME=/usr \
    -DZSTD_HOME=/usr/local \
    -DCMAKE_POLICY_DEFAULT_CMP0074=NEW \
    -DProtobuf_ROOT=$PROTOBUF_PREFIX \
    -DPROTOBUF_HOME=$PROTOBUF_PREFIX \
    -DPROTOBUF_EXECUTABLE=$PROTOBUF_PREFIX/bin/protoc \
    -DSNAPPY_HOME=$SNAPPY_PREFIX \
    -DBUILD_LIBHDFSPP=NO \
    -DBUILD_CPP_TESTS=OFF \
    -DCMAKE_INSTALL_PREFIX=$ORC_PREFIX \
    -DCMAKE_C_COMPILER=$(type -p ${CC})     \
    -DCMAKE_CXX_COMPILER=$(type -p ${CXX})  \
    -DCMAKE_C_FLAGS="$CFLAGS"  \
    -DCMAKE_CXX_FLAGS="$CXXFLAGS -Wno-unused-parameter" \
    "${_CMAKE_EXTRA_CONFIG[@]}" \
    -GNinja ..

ninja
echo  "Installing orc..."
ninja install

cd $WORKDIR


################### boost_cpp installing ##########################
cd /tmp/boost-1.81.0
mkdir Boost_prefix
export BOOST_PREFIX=$(pwd)/Boost_prefix

INCLUDE_PATH="${BOOST_PREFIX}/include"
LIBRARY_PATH="${BOOST_PREFIX}/lib"

export CC=$(which gcc)
export CXX=$(which g++)
export target_platform=$(uname)-$(uname -m)
CXXFLAGS="${CXXFLAGS} -fPIC"
TOOLSET=gcc

 # http://www.boost.org/build/doc/html/bbv2/tasks/crosscompile.html
cat <<EOF > tools/build/example/site-config.jam
using ${TOOLSET} : : ${CXX} ;
EOF

LINKFLAGS="${LINKFLAGS} -L${LIBRARY_PATH}"

CXXFLAGS="$(echo ${CXXFLAGS} | sed 's/ -march=[^ ]*//g' | sed 's/ -mcpu=[^ ]*//g' |sed 's/ -mtune=[^ ]*//g')" \
CFLAGS="$(echo ${CFLAGS} | sed 's/ -march=[^ ]*//g' | sed 's/ -mcpu=[^ ]*//g' |sed 's/ -mtune=[^ ]*//g')" \
    CXX=${CXX_FOR_BUILD:-${CXX}} CC=${CC_FOR_BUILD:-${CC}} ./bootstrap.sh \
    --prefix="${BOOST_PREFIX}" \
    --without-libraries=python \
    --with-toolset=${TOOLSET} \
    --with-icu="${BOOST_PREFIX}" || (cat bootstrap.log; exit 1)
	 ADDRESS_MODEL=64
    ARCHITECTURE=power
	ABI="sysv"
	 BINARY_FORMAT="elf"

	 export CPU_COUNT=$(nproc)

echo " Building and installing Boost...."
./b2 -q \
    variant=release \
    address-model="${ADDRESS_MODEL}" \
    architecture="${ARCHITECTURE}" \
    binary-format="${BINARY_FORMAT}" \
    abi="${ABI}" \
    debug-symbols=off \
    threading=multi \
    runtime-link=shared \
    link=shared \
    toolset=${TOOLSET} \
    include="${INCLUDE_PATH}" \
    cxxflags="${CXXFLAGS} -Wno-deprecated-declarations" \
    linkflags="${LINKFLAGS}" \
    --layout=system \
    -j"${CPU_COUNT}" \
    install

# Remove Python headers as we don't build Boost.Python.
rm "${BOOST_PREFIX}/include/boost/python.hpp"
rm -r "${BOOST_PREFIX}/include/boost/python"

cd $WORKDIR

#######################################################
# Build Pyarrow  (Python package)
#######################################################
echo "Entering Pyarrow source directory..."
cd pyarrow
cd cpp
mkdir -p release && cd release
cmake -DCMAKE_BUILD_TYPE=Release \
      -DCMAKE_INSTALL_PREFIX=/usr/local \
      -DARROW_PYTHON=ON \
      -DARROW_PARQUET=ON \
      -DARROW_ORC=ON \
      -DARROW_FILESYSTEM=ON \
      -DARROW_WITH_LZ4=ON \
      -DARROW_WITH_ZSTD=ON \
      -DARROW_WITH_SNAPPY=ON \
      -DARROW_JSON=ON \
      -DARROW_CSV=ON \
      -DARROW_DATASET=ON \
      -DARROW_S3=ON \
      -DARROW_BUILD_TESTS=OFF \
      -DARROW_SUBSTRAIT=ON \
      -DBoost_DIR=${BOOST_PREFIX} \
      -DBoost_INCLUDE_DIR=${BOOST_PREFIX}/include/ \
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

