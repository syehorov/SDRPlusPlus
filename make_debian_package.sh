#!/bin/sh

# Create directory structure
echo Create directory structure
mkdir sdrpp_debian_amd64
mkdir sdrpp_debian_amd64/DEBIAN

# Create package info
echo Create package info
echo Package: sdrpp >> sdrpp_debian_amd64/DEBIAN/control
echo Version: 1.2.1-15 >> sdrpp_debian_amd64/DEBIAN/control
echo Maintainer: syehorov >> sdrpp_debian_amd64/DEBIAN/control
echo Architecture: all >> sdrpp_debian_amd64/DEBIAN/control
echo Description: Bloat-free SDR receiver software >> sdrpp_debian_amd64/DEBIAN/control
echo Depends: libiio0, libad9361-0, libhackrf0, libairspy0, libairspyhf1, librtaudio7, librtlsdr0, libbladerf2, liblimesuite23.11-1, libuhd4.9.0, libglfw3, sdrplay-api, libsoapysdr0.8, libvolk3.3 >> sdrpp_debian_amd64/DEBIAN/control


# Copying files
ORIG_DIR=$PWD
mkdir build
cd build && cmake ../ && make -j${1}
make install DESTDIR=$ORIG_DIR/sdrpp_debian_amd64
cd $ORIG_DIR
mkdir -p $ORIG_DIR/sdrpp_debian_amd64/usr/include/sdrpp_core/src
mkdir -p $ORIG_DIR/sdrpp_debian_amd64/usr/share/cmake/Modules
cd $ORIG_DIR/core/src
find . -regex ".*\.\(h\|hpp\)" -exec cp --parents \{\} $ORIG_DIR/sdrpp_debian_amd64/usr/include/sdrpp_core/src \;
cp $ORIG_DIR/sdrpp_module.cmake $ORIG_DIR/sdrpp_debian_amd64/usr/share/cmake/Modules

# Create package
echo Create package
cd $ORIG_DIR
dpkg-deb --build sdrpp_debian_amd64

# Cleanup
echo Cleanup
rm -rf sdrpp_debian_amd64 && rm -rf build
