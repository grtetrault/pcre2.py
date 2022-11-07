cmake_minimum_required(VERSION 3.7.2)

project(pcre2)
set(CMAKE_POSITION_INDEPENDENT_CODE ON)

set(CMAKE_C_STANDARD 99)

set(PCRE2_INCLUDE_DIR ${CMAKE_BINARY_DIR}/src/libpcre2)
set(CYTHON_EXTRA_COMPILE_ARGS -DPCRE2_CODE_UNIT_WIDTH=8)

# Always make a release build.
set(CMAKE_BUILD_TYPE Release)

# Build PCRE2 library as static.
set(BUILD_SHARED_LIBS OFF)
add_subdirectory(src/libpcre2)

# Build Cython code as shared.
set(BUILD_SHARED_LIBS ON)
add_subdirectory(src/pcre2)

# Include PCRE2 header for Cython API.
install(FILES ${PCRE2_INCLUDE_DIR}/pcre2.h DESTINATION src/pcre2)
