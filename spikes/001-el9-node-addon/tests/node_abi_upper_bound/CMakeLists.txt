cmake_minimum_required(VERSION 3.10)
project(node_abi_upper_bound CXX)

if(NOT DEFINED MODULE_PATH OR NOT DEFINED MAX_ABI)
    message(FATAL_ERROR "MODULE_PATH and MAX_ABI are required")
endif()

set(NODE_MODULE_CACHE_DIR "${CMAKE_BINARY_DIR}/node-cache")
file(MAKE_DIRECTORY "${NODE_MODULE_CACHE_DIR}/node")
file(WRITE "${NODE_MODULE_CACHE_DIR}/empty.cpp" "")
file(WRITE "${NODE_MODULE_CACHE_DIR}/node/index.tab"
    "version\tdate\tfiles\tnpm\tv8\tuv\tzlib\topenssl\tmodules\tlts\n"
    "v20.0.0\t2023-01-01\t-\t-\t-\t-\t-\t-\t115\t-\n"
    "v22.0.0\t2024-01-01\t-\t-\t-\t-\t-\t-\t127\t-\n"
    "v24.0.0\t2025-01-01\t-\t-\t-\t-\t-\t-\t137\t-\n"
    "v25.0.0\t2025-06-01\t-\t-\t-\t-\t-\t-\t141\t-\n"
    "v26.0.0\t2026-01-01\t-\t-\t-\t-\t-\t-\t147\t-\n")
foreach(version IN ITEMS v20.0.0 v22.0.0 v24.0.0 v25.0.0 v26.0.0)
    file(MAKE_DIRECTORY "${NODE_MODULE_CACHE_DIR}/node/${version}")
    file(WRITE "${NODE_MODULE_CACHE_DIR}/node/${version}/node.h" "")
endforeach()

include("${MODULE_PATH}")
file(WRITE "${CMAKE_CURRENT_BINARY_DIR}/stub.cpp" "void node_abi_upper_bound_stub() {}\n")
add_node_module(test-addon MINIMUM_NODE_ABI 115 MAXIMUM_NODE_ABI "${MAX_ABI}")
target_sources(test-addon INTERFACE "${CMAKE_CURRENT_BINARY_DIR}/stub.cpp")

foreach(abi IN ITEMS 115 127 137)
    if(NOT TARGET test-addon.abi-${abi})
        message(FATAL_ERROR "Expected ABI ${abi} target was not generated")
    endif()
endforeach()
foreach(abi IN ITEMS 141 147)
    if(TARGET test-addon.abi-${abi})
        message(FATAL_ERROR "ABI ${abi} exceeds MAX_ABI=${MAX_ABI} but was generated")
    endif()
endforeach()
