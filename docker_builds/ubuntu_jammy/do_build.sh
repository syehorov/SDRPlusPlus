#!/bin/bash
set -e
cd /root

# Install dependencies and tools
apt update
apt install -y build-essential cmake git libfftw3-dev libglfw3-dev libvolk2-dev libzstd-dev libairspyhf-dev libairspy-dev \
            libiio-dev libad9361-dev librtaudio-dev libhackrf-dev librtlsdr-dev libbladerf-dev liblimesuite-dev p7zip-full wget portaudio19-dev \
            libcodec2-dev autoconf libtool xxd libspdlog-dev libsoapysdr-dev libuhd-dev

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
cmake .. -DOPT_BUILD_BLADERF_SOURCE=ON -DOPT_BUILD_LIMESDR_SOURCE=ON -DOPT_BUILD_SDRPLAY_SOURCE=ON -DOPT_BUILD_NEW_PORTAUDIO_SINK=ON -DOPT_BUILD_M17_DECODER=ON -DOPT_BUILD_PERSEUS_SOURCE=ON -DOPT_BUILD_RFNM_SOURCE=ON -DOPT_BUILD_FOBOSSDR_SOURCE=ON
make VERBOSE=1 -j2

cd ..
mkdir sdrpp_debian_amd64
mkdir sdrpp_debian_amd64/DEBIAN

# Create package info
echo Create package info
echo Package: sdrpp >> sdrpp_debian_amd64/DEBIAN/control
echo Version: 1.2.1$BUILD_NO >> sdrpp_debian_amd64/DEBIAN/control
echo Maintainer: Serhii Yehorov >> sdrpp_debian_amd64/DEBIAN/control
echo Architecture: all >> sdrpp_debian_amd64/DEBIAN/control
echo Description: Bloat-free SDR receiver software >> sdrpp_debian_amd64/DEBIAN/control
echo Depends: libiio0, libad9361-0, libhackrf0, libairspy0, libairspyhf1, librtaudio7, librtlsdr0, libbladerf2, liblimesuite23.11-1, libuhd4.7.0, libglfw3, sdrplay-api, libsoapysdr0.8 >> sdrpp_debian_amd64/DEBIAN/control

# Copying files
ORIG_DIR=$PWD
cd $1
make install DESTDIR=$ORIG_DIR/sdrpp_debian_amd64
cd $ORIG_DIR

# Create package
echo Create package
dpkg-deb --build sdrpp_debian_amd64

# Cleanup
echo Cleanup
rm -rf sdrpp_debian_amd64