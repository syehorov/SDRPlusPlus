cmake_minimum_required(VERSION 3.13)
project(recorder)

file(GLOB SRC "src/*.cpp")

include(${SDRPP_MODULE_CMAKE})

find_library(LAME_LIBRARY NAMES mp3lame)
find_library(VORBISENC_LIBRARY NAMES vorbisenc)
find_library(VORBIS_LIBRARY NAMES vorbis)
find_library(OGG_LIBRARY NAMES ogg)
find_path(VORBIS_INCLUDE_DIR vorbis/vorbisenc.h)
find_path(OGG_INCLUDE_DIR ogg/ogg.h)
find_path(LAME_INCLUDE_DIR lame/lame.h)

if (NOT LAME_LIBRARY OR NOT LAME_INCLUDE_DIR)
    message(FATAL_ERROR "LAME (libmp3lame) not found")
endif()

list(APPEND INCLUDE_DIRS ${LAME_INCLUDE_DIR})
list(APPEND INCLUDE_DIRS ${VORBIS_INCLUDE_DIR} ${OGG_INCLUDE_DIR})
target_link_libraries(recorder PRIVATE mp3lame)
target_link_libraries(recorder PRIVATE vorbisenc vorbis ogg)
target_include_directories(recorder PRIVATE "src/")
target_include_directories(recorder PRIVATE "../../decoder_modules/radio/src")