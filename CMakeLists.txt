cmake_minimum_required(VERSION 3.23)

# Set compilers to Clang before project() call (can be overridden by environment)
if(NOT CMAKE_C_COMPILER)
    set(CMAKE_C_COMPILER clang)
endif()
if(NOT CMAKE_CXX_COMPILER)
    set(CMAKE_CXX_COMPILER clang++)
endif()

project(mlir_tools_superbuild C CXX)

include(ExternalProject)

# ==============================================================================
# Generator Selection Mechanism
# ==============================================================================

# Define a CMake option to select the desired generator.
# Users will set this with -DGEN_TYPE=<value> on the CMake command line.
set(CMAKE_GENERATOR_IDENTIFIER "MSVC" CACHE STRING "Select the CMake generator type (MSVC or NINJA)")

# Determine the actual generator and platform arguments based on GEN_TYPE
if (CMAKE_GENERATOR_IDENTIFIER STREQUAL "MSVC")
    set(SUPERBUILD_CMAKE_GENERATOR "Visual Studio 17 2022")
    set(SUPERBUILD_CMAKE_GENERATOR_PLATFORM "x64")
    set(SUPERBUILD_CMAKE_TOOLSET_ARGS "-T;host=x64") # For MSVC, specify host toolset
    set(SUPERBUILD_PLATFORM_ARGS "-A;${SUPERBUILD_CMAKE_GENERATOR_PLATFORM}")
    message(STATUS "Configuring for MSVC Generator: ${SUPERBUILD_CMAKE_GENERATOR}")
elseif (CMAKE_GENERATOR_IDENTIFIER STREQUAL "NINJA")
    set(SUPERBUILD_CMAKE_GENERATOR "Ninja")
    set(SUPERBUILD_CMAKE_GENERATOR_PLATFORM "") # Ninja doesn't typically use -A/-T
    set(SUPERBUILD_CMAKE_TOOLSET_ARGS "") # No specific toolset args for Ninja
    set(SUPERBUILD_PLATFORM_ARGS "") # No platform args for Ninja
    message(STATUS "Configuring for Ninja Generator")
else ()
    message(FATAL_ERROR "Unsupported CMAKE_GENERATOR_IDENTIFIER: ${CMAKE_GENERATOR_IDENTIFIER}. Please choose MSVC or NINJA.")
endif ()

# ==============================================================================
# LLVM Configuration
# ==============================================================================
set(LLVM_SOURCE_DIR ${CMAKE_SOURCE_DIR}/ext/llvm-project/llvm)
set(LLVM_BINARY_DIR ${CMAKE_BINARY_DIR}/ext/llvm-build)
set(LLVM_INSTALL_DIR ${CMAKE_BINARY_DIR}/ext/llvm-install)

# Build the CMAKE_ARGS list conditionally
set(LLVM_CMAKE_ARGS
    -DCMAKE_INSTALL_PREFIX=${LLVM_INSTALL_DIR}
    -DLLVM_ENABLE_PROJECTS=mlir
    -DMLIR_ENABLE_BINDINGS_PYTHON=ON
    -DLLVM_TARGETS_TO_BUILD=host
    -DLLVM_ENABLE_ASSERTIONS=ON
    # Add these critical flags for torch-mlir compatibility:
    -DLLVM_INSTALL_UTILS=ON
    -DLLVM_BUILD_UTILS=ON
    -DLLVM_INCLUDE_UTILS=ON
    -DLLVM_BUILD_TOOLS=ON
    -DLLVM_INCLUDE_TOOLS=ON
    # Use Clang for consistency
    -DCMAKE_C_COMPILER=clang
    -DCMAKE_CXX_COMPILER=clang++
    # For CI builds use the less voluminous Release build
    -DCMAKE_BUILD_TYPE=Release
    -G "${SUPERBUILD_CMAKE_GENERATOR}"
)

# Add platform-specific arguments only if they're not empty
if(SUPERBUILD_PLATFORM_ARGS)
    list(APPEND LLVM_CMAKE_ARGS ${SUPERBUILD_PLATFORM_ARGS})
endif()

if(SUPERBUILD_CMAKE_TOOLSET_ARGS)
    list(APPEND LLVM_CMAKE_ARGS ${SUPERBUILD_CMAKE_TOOLSET_ARGS})
endif()

# Determine install command based on generator
if(CMAKE_GENERATOR_IDENTIFIER STREQUAL "NINJA")
    set(LLVM_INSTALL_COMMAND ${CMAKE_COMMAND} --build . --target install)
else()
    set(LLVM_INSTALL_COMMAND ${CMAKE_COMMAND} --build . --target install --config Release)
endif()

ExternalProject_Add(llvm-project
    SOURCE_DIR ${LLVM_SOURCE_DIR}
    BINARY_DIR ${LLVM_BINARY_DIR}
    CMAKE_ARGS ${LLVM_CMAKE_ARGS}
    INSTALL_DIR ${LLVM_INSTALL_DIR}
    INSTALL_COMMAND ${LLVM_INSTALL_COMMAND}
    # Use a specific LLVM commit that's compatible with torch-mlir
    #GIT_REPOSITORY https://github.com/llvm/llvm-project.git
    #GIT_TAG 5fcf907b34355980f77d7665a175b05fea7a6b7b  # Known good commit from late January 2024
)

# ==============================================================================
# Torch-MLIR Configuration
# ==============================================================================
set(TORCHMLIR_SOURCE_DIR ${CMAKE_SOURCE_DIR}/ext/torch-mlir)
set(TORCHMLIR_BINARY_DIR ${CMAKE_BINARY_DIR}/ext/torch-mlir-build)
set(TORCHMLIR_INSTALL_DIR ${CMAKE_BINARY_DIR}/ext/torch-mlir-install)

# Build the CMAKE_ARGS list conditionally for torch-mlir
set(TORCHMLIR_CMAKE_ARGS
    -DCMAKE_PREFIX_PATH=${TORCHMLIR_INSTALL_DIR}
    -DMLIR_DIR=${LLVM_INSTALL_DIR}/lib/cmake/mlir
    -DLLVM_DIR=${LLVM_INSTALL_DIR}/lib/cmake/llvm
    -DCMAKE_BUILD_TYPE=Release
    -DLLVM_ENABLE_ASSERTIONS=ON
    -DLLVM_EXTERNAL_PROJECTS="torch-mlir"
    -DLLVM_EXTERNAL_TORCH_MLIR_SOURCE_DIR=${TORCHMLIR_SOURCE_DIR}
    -DPython3_EXECUTABLE=/usr/bin/python3.10
    -DPython3_INCLUDE_DIR=/usr/include/python3.10
    # Use Clang for consistency
    -DCMAKE_C_COMPILER=clang
    -DCMAKE_CXX_COMPILER=clang++
    -G "${SUPERBUILD_CMAKE_GENERATOR}"
)

# Add platform-specific arguments only if they're not empty
if(SUPERBUILD_PLATFORM_ARGS)
    list(APPEND TORCHMLIR_CMAKE_ARGS ${SUPERBUILD_PLATFORM_ARGS})
endif()

if(SUPERBUILD_CMAKE_TOOLSET_ARGS)
    list(APPEND TORCHMLIR_CMAKE_ARGS ${SUPERBUILD_CMAKE_TOOLSET_ARGS})
endif()

ExternalProject_Add(torch-mlir
    SOURCE_DIR ${TORCHMLIR_SOURCE_DIR}
    BINARY_DIR ${TORCHMLIR_BINARY_DIR}
    CMAKE_ARGS ${TORCHMLIR_CMAKE_ARGS}
    DEPENDS llvm-project
)
