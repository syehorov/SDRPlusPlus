cmake_minimum_required(VERSION 3.13)
project(recorder_lame)

file(GLOB SRC "src/*.cpp")

include(${SDRPP_MODULE_CMAKE})

target_include_directories(recorder_lame PRIVATE "src/")
target_include_directories(recorder_lame PRIVATE "../../decoder_modules/radio/src")