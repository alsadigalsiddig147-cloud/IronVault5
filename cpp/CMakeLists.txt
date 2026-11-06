cmake_minimum_required(VERSION 3.4.1)

project("iron_core")

add_library(
    iron_core
    SHARED
    iron_core.cpp
)

find_library(
    log-lib
    log
)

target_link_libraries(
    iron_core
    ${log-lib}
)
