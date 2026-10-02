cmake_minimum_required(VERSION 3.20)
project(ocho_kart_recomp LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Phase 0 "hello world" build. This is replaced by the real ReXGlue build in Phase 3.
add_executable(ocho_kart_recomp
    src/main.cpp
)