#!/bin/bash
set -e
cd /root

# Install dependencies and tools
apt update
apt install -y build-essential cmake git libfftw3-dev libglfw3-dev libvolk-dev libzstd-dev libairspyhf-dev libairspy-dev \
            libiio-dev libad9361-dev librtaudio-dev libhackrf-dev librtlsdr-dev libbladerf-dev liblimesuite-dev p7zip-full wget portaudio19-dev \
            libcodec2-dev autoconf libtool xxd libspdlog-dev libsoapysdr-dev libuhd-dev libitpp-dev

# Install SDRPlay libraries
SDRPLAY_ARCH=$(dpkg --print-architecture)
wget https://www.sdrplay.com/software/SDRplay_RSP_API-Linux-3.15.2.run
7z x ./SDRplay_RSP_API-Linux-3.15.2.run
7z x ./SDRplay_RSP_API-Linux-3.15.2
cp $SDRPLAY_ARCH/libsdrplay_api.so.3.15 /usr/lib/libsdrplay_api.so
cp inc/* /usr/include/

# Install libperseus
git clone https://github.com/Microtelecom/libperseus-sdr
cd libperseus-sdr
autoreconf -i
./configure
make
make install
ldconfig
cd ..

# Install librfnm
git clone https://github.com/AlexandreRouma/librfnm
cd librfnm
mkdir build
cd build
cmake .. -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr
make -j2
make install
cd ../../

# Install libfobos
git clone https://github.com/AlexandreRouma/libfobos
cd libfobos
mkdir build
cd build
cmake .. -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr
make -j2
make install
cd ../../

cd SDRPlusPlus
mkdir build
cd build
cmake ..
make VERBOSE=1 -j2

mkdir -p /root/SDRPlusPlus/sdrpp_debian_amd64/DEBIAN

# Create package info
echo Create package info
echo Package: sdrpp >> /root/SDRPlusPlus/sdrpp_debian_amd64/DEBIAN/control
echo Version: 1.2.1$BUILD_NO >> /root/SDRPlusPlus/sdrpp_debian_amd64/DEBIAN/control
echo Maintainer: Serhii Yehorov >> /root/SDRPlusPlus/sdrpp_debian_amd64/DEBIAN/control
echo Architecture: all >> /root/SDRPlusPlus/sdrpp_debian_amd64/DEBIAN/control
echo Description: Bloat-free SDR receiver software >> /root/SDRPlusPlus/sdrpp_debian_amd64/DEBIAN/control
echo Depends: libiio0, libad9361-0, libhackrf0, libairspy0, libairspyhf1, librtaudio7, librtlsdr0, libbladerf2, liblimesuite23.11-1, libuhd4.7.0, libglfw3, sdrplay-api, libsoapysdr0.8 >> /root/SDRPlusPlus/sdrpp_debian_amd64/DEBIAN/control

# Copying files
cd /root/SDRPlusPlus/build
make install DESTDIR=/root/SDRPlusPlus/sdrpp_debian_amd64
mkdir -p /root/SDRPlusPlus/sdrpp_debian_amd64/usr/include/sdrpp_core/src
mkdir -p /root/SDRPlusPlus/sdrpp_debian_amd64/usr/share/cmake/Modules
cd /root/SDRPlusPlus/core/src
find . -regex ".*\.\(h\|hpp\)" -exec cp --parents \{\} /root/SDRPlusPlus/sdrpp_debian_amd64/usr/include/sdrpp_core/src \;
cp /root/SDRPlusPlus/sdrpp_module.cmake /root/SDRPlusPlus/sdrpp_debian_amd64/usr/share/cmake/Modules

# Create package
echo Create package
cd /root/SDRPlusPlus/
dpkg-deb --build sdrpp_debian_amd64

# Cleanup
echo Cleanup
rm -rf /root/SDRPlusPlus/sdrpp_debian_amd64