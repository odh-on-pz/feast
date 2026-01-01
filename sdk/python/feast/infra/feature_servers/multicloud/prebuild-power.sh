echo "Entering rapidson source directory..."
cd rapidjson
mkdir build && cd build
echo "Running cmake to configure the rapidjson build..."
cmake .. -DCMAKE_INSTALL_PREFIX=/usr/local
echo "Compiling the source code for rapidjson..."
make -j$(nproc)
echo "Installing rapidjson"
make install
