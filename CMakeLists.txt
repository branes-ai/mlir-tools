cmake_minimum_required(VERSION 3.23)
project(mlir_tools_superbuild C CXX)

# Set compilers to Clang before project() call (can be overridden by environment)
if(NOT CMAKE_C_COMPILER)
    set(CMAKE_C_COMPILER clang)
endif()
if(NOT CMAKE_CXX_COMPILER)
    set(CMAKE_CXX_COMPILER clang++)
endif()

# When using the CMake GUI, we need to point to the venv python required
# The python dependencies, pybind11, nanobind, and numpy need to be installed in this venv
# for the build to work. 
# With Linux this is all dynamically picked up the shell environment.
set(PYTHON_EXECUTABLE "D:/Python/venv/p310/Scripts/python.exe" CACHE FILEPATH "Python executable")

# ==============================================================================
# Python Environment Configuration
# ==============================================================================
#
# Usage on Windows
# 
# first activate your virtual environment
# source /path/to/venv/bin/activate    # Linux/Mac
# or
# C:\path\to\venv\Scripts\activate.bat  # Windows
#
# Then run cmake (it will automatically find the activated Python)
# cmake -DCMAKE_GENERATOR_IDENTIFIER=MSVC ..
#
# When using CMake GUI 
# 1. open a shell
# 2. activate the venv 
#     C:\path\to\venv\Scripts\activate.bat
# 3. Launch CMake GUI from the activated environment
#     cmake-gui
# This way, CMake GUI inherits the virtual environment's PATH and environment variables.
#
# Allow overriding Python executable via command line: -DPYTHON_EXECUTABLE=path/to/python

# ==============================================================================
# Python Environment Configuration (GUI-friendly)
# ==============================================================================
#
# Option 1: Check for explicitly set PYTHON_EXECUTABLE (from GUI or command line)
if(PYTHON_EXECUTABLE)
    message(STATUS "Using explicitly set Python: ${PYTHON_EXECUTABLE}")
else()
    # Option 2: Check if we're in an activated virtual environment
    if(DEFINED ENV{VIRTUAL_ENV})
        message(STATUS "Virtual environment detected: $ENV{VIRTUAL_ENV}")
        if(WIN32)
            set(VENV_PYTHON "$ENV{VIRTUAL_ENV}/Scripts/python.exe")
        else()
            set(VENV_PYTHON "$ENV{VIRTUAL_ENV}/bin/python")
        endif()
        
        if(EXISTS ${VENV_PYTHON})
            set(PYTHON_EXECUTABLE ${VENV_PYTHON})
            message(STATUS "Using virtual environment Python: ${PYTHON_EXECUTABLE}")
        endif()
    endif()
    
    # Option 3: Fallback to specific Python
    if(NOT PYTHON_EXECUTABLE)
        set(PYTHON_EXECUTABLE /usr/bin/python3.10)
        message(STATUS "Using specific Python: ${PYTHON_EXECUTABLE}")

        #find_program(PYTHON_EXECUTABLE python REQUIRED)
        #message(STATUS "Using system Python: ${PYTHON_EXECUTABLE}")
    endif()
endif()

# Get Python version and include directory
execute_process(
    COMMAND ${PYTHON_EXECUTABLE} -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')"
    OUTPUT_VARIABLE PYTHON_VERSION
    OUTPUT_STRIP_TRAILING_WHITESPACE
)

execute_process(
    COMMAND ${PYTHON_EXECUTABLE} -c "import sysconfig; print(sysconfig.get_path('include'))"
    OUTPUT_VARIABLE PYTHON_INCLUDE_DIR
    OUTPUT_STRIP_TRAILING_WHITESPACE
)

message(STATUS "Using Python: ${PYTHON_EXECUTABLE}")
message(STATUS "Python version: ${PYTHON_VERSION}")
message(STATUS "Python include dir: ${PYTHON_INCLUDE_DIR}")

# Verify the Python works and has pybind11
execute_process(
    COMMAND ${PYTHON_EXECUTABLE} -c "import sys, pybind11; print(f'Python: {sys.executable}'); print(f'pybind11: {pybind11.__version__}')"
    RESULT_VARIABLE PYBIND_TEST_RESULT
    OUTPUT_VARIABLE PYBIND_TEST_OUTPUT
)

if(NOT PYBIND_TEST_RESULT EQUAL 0)
    message(FATAL_ERROR " Pybind11 not found: please install in the selected venv first (typically: python -m pip install pybind11)")
else()
    message(STATUS "Pybind11 installed: ${PYBIND_TEST_OUTPUT}")
endif()

# Verify the Python venv has nanobind
execute_process(
    COMMAND ${PYTHON_EXECUTABLE} -c "import sys, nanobind; print(f'Python: {sys.executable}'); print(f'nanobind: {nanobind.__version__}')"
    RESULT_VARIABLE NANOBIND_TEST_RESULT
    OUTPUT_VARIABLE NANOBIND_TEST_OUTPUT
)

if(NOT NANOBIND_TEST_RESULT EQUAL 0)
    message(FATAL_ERROR "Nanobind not found: please install in the selected venv first (typically: python -m pip install nanobind)")
else()
    message(STATUS "Nanobind installed: ${NANOBIND_TEST_OUTPUT}")
endif()

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
    -DPython3_EXECUTABLE=${PYTHON_EXECUTABLE}
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
    -DPython3_EXECUTABLE=${PYTHON_EXECUTABLE}
    -DPython3_INCLUDE_DIR=${PYTHON_INCLUDE_DIR}
    #-DPython3_EXECUTABLE=/usr/bin/python3.10
    #-DPython3_INCLUDE_DIR=/usr/include/python3.10
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
