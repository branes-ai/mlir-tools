cmake_minimum_required(VERSION 3.23)
project(mlir_tools C CXX)

# ==============================================================================
# Basic Configuration
# ==============================================================================

# C++ standard requirements (align with LLVM/MLIR)
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

# Build configuration
if(NOT CMAKE_BUILD_TYPE)
    set(CMAKE_BUILD_TYPE Release)
endif()

# ==============================================================================
# Find Dependencies
# ==============================================================================

# Torch-MLIR installation directory (passed from superbuild)
if(NOT TORCHMLIR_INSTALL_DIR)
    message(FATAL_ERROR "TORCHMLIR_INSTALL_DIR must be specified")
endif()

# Convert to absolute path
get_filename_component(TORCHMLIR_INSTALL_DIR "${TORCHMLIR_INSTALL_DIR}" ABSOLUTE)
message(STATUS "Using Torch-MLIR installation: ${TORCHMLIR_INSTALL_DIR}")

# Add the torch-mlir install directory to CMAKE_PREFIX_PATH
list(APPEND CMAKE_PREFIX_PATH "${TORCHMLIR_INSTALL_DIR}")

# Find MLIR (from torch-mlir installation)
find_package(MLIR REQUIRED CONFIG HINTS "${TORCHMLIR_INSTALL_DIR}/lib/cmake/mlir")
message(STATUS "Using MLIRConfig.cmake in: ${MLIR_DIR}")

# Find LLVM (from torch-mlir installation)
find_package(LLVM REQUIRED CONFIG HINTS "${TORCHMLIR_INSTALL_DIR}/lib/cmake/llvm")
message(STATUS "Using LLVMConfig.cmake in: ${LLVM_DIR}")

# Find TorchMLIR (from torch-mlir installation)
find_package(TorchMLIR REQUIRED CONFIG HINTS "${TORCHMLIR_INSTALL_DIR}/lib/cmake/torch-mlir")
message(STATUS "Using TorchMLIRConfig.cmake in: ${TorchMLIR_DIR}")

# ==============================================================================
# LLVM/MLIR Configuration
# ==============================================================================

# Include LLVM/MLIR configurations
list(APPEND CMAKE_MODULE_PATH "${MLIR_CMAKE_DIR}")
list(APPEND CMAKE_MODULE_PATH "${LLVM_CMAKE_DIR}")

include(TableGen)
include(AddLLVM)
include(AddMLIR)
include(HandleLLVMOptions)

# LLVM/MLIR include directories
include_directories(SYSTEM ${LLVM_INCLUDE_DIRS})
include_directories(SYSTEM ${MLIR_INCLUDE_DIRS})

# Torch-MLIR include directories
include_directories(SYSTEM "${TORCHMLIR_INSTALL_DIR}/include")

# Add definitions
separate_arguments(LLVM_DEFINITIONS_LIST NATIVE_COMMAND ${LLVM_DEFINITIONS})
add_definitions(${LLVM_DEFINITIONS_LIST})

# ==============================================================================
# Compiler Configuration
# ==============================================================================

# Platform-specific compiler settings
if(WIN32)
    # Windows-specific settings
    add_compile_definitions(_CRT_SECURE_NO_WARNINGS)
    add_compile_definitions(_SCL_SECURE_NO_WARNINGS)
else()
    # Unix-like systems
    add_compile_options(-fPIC)
endif()

# Enable additional warnings for our code
if(CMAKE_CXX_COMPILER_ID MATCHES "Clang" OR CMAKE_CXX_COMPILER_ID STREQUAL "GNU")
    add_compile_options(-Wall -Wextra -Wno-unused-parameter)
endif()

# ==============================================================================
# Testing Configuration
# ==============================================================================

# Find lit tool for testing
find_program(LLVM_LIT_PATH 
    NAMES llvm-lit lit.py lit
    PATHS "${TORCHMLIR_INSTALL_DIR}/bin" "${LLVM_TOOLS_BINARY_DIR}"
    DOC "Path to llvm-lit tool"
)

if(NOT LLVM_LIT_PATH)
    message(WARNING "Could not find llvm-lit tool. Tests will not be available.")
else()
    message(STATUS "Found llvm-lit: ${LLVM_LIT_PATH}")
endif()

# Find FileCheck tool for testing
find_program(FILECHECK_PATH
    NAMES FileCheck
    PATHS "${TORCHMLIR_INSTALL_DIR}/bin" "${LLVM_TOOLS_BINARY_DIR}"
    DOC "Path to FileCheck tool"
)

if(NOT FILECHECK_PATH)
    message(WARNING "Could not find FileCheck tool. Tests may not work properly.")
else()
    message(STATUS "Found FileCheck: ${FILECHECK_PATH}")
endif()

# ==============================================================================
# Global Target Configuration
# ==============================================================================

# Function to create MLIR tools with consistent settings
function(add_mlir_tool tool_name)
    cmake_parse_arguments(ARG "" "" "SRCS;LIBS;DEPENDS" ${ARGN})
    
    add_llvm_executable(${tool_name} ${ARG_SRCS})
    
    # Link against required libraries
    target_link_libraries(${tool_name} PRIVATE
        ${ARG_LIBS}
        # Core MLIR libraries
        MLIRIR
        MLIRParser
        MLIRPass
        MLIRTransforms
        MLIRSupport
        # Torch-MLIR libraries
        TorchMLIRTorchDialect
        TorchMLIRTorchONNXDialect
        TorchMLIRConversionTorchONNXToTorch
        TorchMLIRConversionTorchToLinalg
    )
    
    # Add dependencies
    if(ARG_DEPENDS)
        add_dependencies(${tool_name} ${ARG_DEPENDS})
    endif()
    
    # Install the tool
    install(TARGETS ${tool_name} DESTINATION bin)
endfunction()

# ==============================================================================
# Add Subdirectories
# ==============================================================================

# Add common utilities
add_subdirectory(common)

# Add tools
add_subdirectory(onnx_c_importer)

# ==============================================================================
# Testing Setup
# ==============================================================================

if(LLVM_LIT_PATH AND FILECHECK_PATH)
    # Configure lit configuration
    configure_file(
        ${CMAKE_CURRENT_SOURCE_DIR}/test/lit.site.cfg.py.in
        ${CMAKE_CURRENT_BINARY_DIR}/test/lit.site.cfg.py
        @ONLY
    )
    
    # Add test target
    add_custom_target(check-mlir-tools
        COMMAND ${LLVM_LIT_PATH} -v ${CMAKE_CURRENT_BINARY_DIR}/test
        WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}
        COMMENT "Running mlir-tools tests"
        USES_TERMINAL
    )
    
    # Add test directory
    add_subdirectory(test)
else()
    message(STATUS "Testing disabled: missing llvm-lit or FileCheck")
endif()

# ==============================================================================
# Summary
# ==============================================================================

message(STATUS "==== MLIR Tools Configuration Summary ====")
message(STATUS "Build type: ${CMAKE_BUILD_TYPE}")
message(STATUS "C++ standard: ${CMAKE_CXX_STANDARD}")
message(STATUS "LLVM version: ${LLVM_PACKAGE_VERSION}")
message(STATUS "MLIR directory: ${MLIR_DIR}")
message(STATUS "Torch-MLIR directory: ${TORCHMLIR_INSTALL_DIR}")
message(STATUS "Install prefix: ${CMAKE_INSTALL_PREFIX}")
if(LLVM_LIT_PATH)
    message(STATUS "Testing enabled with lit: ${LLVM_LIT_PATH}")
else()
    message(STATUS "Testing disabled")
endif()
message(STATUS "========================================")
