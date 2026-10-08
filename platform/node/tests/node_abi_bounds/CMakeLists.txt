cmake_minimum_required(VERSION 3.10)
project(node_abi_bounds CXX)

if(NOT DEFINED MODULE_PATH OR NOT DEFINED BOUND_MODE)
    message(FATAL_ERROR "MODULE_PATH and BOUND_MODE are required")
endif()

# Keep this fixture entirely offline: the index and header sentinels replace
# the external Node downloads that add_node_module would otherwise request.
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
file(WRITE "${CMAKE_CURRENT_BINARY_DIR}/stub.cpp" "void node_abi_bounds_stub() {}\n")
if(BOUND_MODE STREQUAL "global")
    set(NODE_MODULE_MAXIMUM_ABI 137)
    add_node_module(test-addon MINIMUM_NODE_ABI 115)
    set(expected_abis 115 127 137)
elseif(BOUND_MODE STREQUAL "explicit")
    # The per-module argument must take precedence over the global default.
    set(NODE_MODULE_MAXIMUM_ABI 127)
    add_node_module(test-addon MINIMUM_NODE_ABI 115 MAXIMUM_NODE_ABI 137)
    set(expected_abis 115 127 137)
elseif(BOUND_MODE STREQUAL "uncapped")
    add_node_module(test-addon MINIMUM_NODE_ABI 115)
    set(expected_abis 115 127 137 141 147)
elseif(BOUND_MODE STREQUAL "filtered")
    # The maximum must compose with the existing minimum and exclusion filters.
    set(NODE_MODULE_MAXIMUM_ABI 137)
    add_node_module(test-addon MINIMUM_NODE_ABI 127 EXCLUDE_NODE_ABIS 127)
    set(expected_abis 137)
else()
    message(FATAL_ERROR "Unknown BOUND_MODE: ${BOUND_MODE}")
endif()
target_sources(test-addon INTERFACE "${CMAKE_CURRENT_BINARY_DIR}/stub.cpp")

foreach(abi IN ITEMS 115 127 137 141 147)
    list(FIND expected_abis "${abi}" expected_index)
    if(expected_index EQUAL -1 AND TARGET test-addon.abi-${abi})
        message(FATAL_ERROR "Unexpected ABI ${abi} target in ${BOUND_MODE} mode")
    elseif(NOT expected_index EQUAL -1 AND NOT TARGET test-addon.abi-${abi})
        message(FATAL_ERROR "Expected ABI ${abi} target was not generated in ${BOUND_MODE} mode")
    endif()
endforeach()
