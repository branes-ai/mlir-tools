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
# Torch-MLIR Configuration
# ==============================================================================
set(TORCHMLIR_SOURCE_DIR ${CMAKE_SOURCE_DIR}/ext/torch-mlir)
set(TORCHMLIR_BINARY_DIR ${CMAKE_BINARY_DIR}/ext/torch-mlir-build)
set(TORCHMLIR_INSTALL_DIR ${CMAKE_BINARY_DIR}/ext/torch-mlir-install)

# Convert paths to use forward slashes for CMake
file(TO_CMAKE_PATH "${TORCHMLIR_INSTALL_DIR}" TORCHMLIR_INSTALL_DIR_CMAKE)
file(TO_CMAKE_PATH "${PYTHON_EXECUTABLE}" PYTHON_EXECUTABLE_CMAKE)
file(TO_CMAKE_PATH "${PYTHON_INCLUDE_DIR}" PYTHON_INCLUDE_DIR_CMAKE)

# Build the CMAKE_ARGS list for torch-mlir
set(TORCHMLIR_CMAKE_ARGS
    "-DCMAKE_INSTALL_PREFIX=${TORCHMLIR_INSTALL_DIR_CMAKE}"
    "-DCMAKE_BUILD_TYPE=Release"
    "-DLLVM_ENABLE_ASSERTIONS=ON"
    
    # Python configuration
    "-DPython3_EXECUTABLE=${PYTHON_EXECUTABLE_CMAKE}"
    "-DPython3_INCLUDE_DIR=${PYTHON_INCLUDE_DIR_CMAKE}"
    
    # Compiler configuration
    "-DCMAKE_C_COMPILER=clang"
    "-DCMAKE_CXX_COMPILER=clang++"
    
    # Torch-MLIR specific options
    "-DTORCH_MLIR_ENABLE_BINDINGS_PYTHON=ON"
    "-DTORCH_MLIR_OUT_OF_TREE_BUILD=OFF"
    "-DTORCH_MLIR_USE_INSTALLED_PYTORCH=ON"
    
    # LLVM/MLIR options (using torch-mlir's internal LLVM)
    "-DMLIR_ENABLE_BINDINGS_PYTHON=ON"
    "-DLLVM_ENABLE_PROJECTS=mlir"
    "-DLLVM_TARGETS_TO_BUILD=X86;NVPTX;AMDGPU"
    "-DLLVM_ENABLE_TERMINFO=OFF"
    "-DLLVM_ENABLE_LIBEDIT=OFF"
    "-DLLVM_ENABLE_LIBXML2=OFF"
    "-DLLVM_ENABLE_ZLIB=OFF"
    "-DLLVM_ENABLE_ZSTD=OFF"
    "-DLLVM_PARALLEL_COMPILE_JOBS=4"
    "-DLLVM_PARALLEL_LINK_JOBS=2"
)

# Don't add platform args to CMAKE_ARGS since we're using dedicated properties
# Platform args will be handled by CMAKE_GENERATOR_PLATFORM and CMAKE_GENERATOR_TOOLSET

# Add Git submodule update step
ExternalProject_Add(torch-mlir
    SOURCE_DIR ${TORCHMLIR_SOURCE_DIR}
    BINARY_DIR ${TORCHMLIR_BINARY_DIR}
    
    # Update submodules (including llvm-project and stablehlo)
    UPDATE_COMMAND ""
    PATCH_COMMAND ${CMAKE_COMMAND} -E chdir ${TORCHMLIR_SOURCE_DIR} 
                  git submodule update --init --recursive
    
    CMAKE_GENERATOR ${SUPERBUILD_CMAKE_GENERATOR}
    CMAKE_GENERATOR_PLATFORM ${SUPERBUILD_CMAKE_GENERATOR_PLATFORM}
    CMAKE_ARGS ${TORCHMLIR_CMAKE_ARGS}
    
    # Build specific targets
    BUILD_COMMAND ${CMAKE_COMMAND} --build <BINARY_DIR> --config Release
    
    # Install
    INSTALL_COMMAND ${CMAKE_COMMAND} --build <BINARY_DIR> --config Release --target install
    
    # Log output for debugging
    LOG_CONFIGURE ON
    LOG_BUILD ON
    LOG_INSTALL ON
)

# ==============================================================================
# Export Configuration
# ==============================================================================

# Create a simple config file for downstream projects
configure_file(
    ${CMAKE_CURRENT_SOURCE_DIR}/torch-mlir-config.cmake.in
    ${CMAKE_BINARY_DIR}/torch-mlir-config.cmake
    @ONLY
)

# Optional: Create an alias target for convenience
add_custom_target(build-torch-mlir DEPENDS torch-mlir)

# Print configuration summary
message(STATUS "==== Torch-MLIR Configuration Summary ====")
message(STATUS "Source directory: ${TORCHMLIR_SOURCE_DIR}")
message(STATUS "Binary directory: ${TORCHMLIR_BINARY_DIR}")
message(STATUS "Install directory: ${TORCHMLIR_INSTALL_DIR}")
message(STATUS "Python executable: ${PYTHON_EXECUTABLE}")
message(STATUS "Python version: ${PYTHON_VERSION}")
message(STATUS "Generator: ${SUPERBUILD_CMAKE_GENERATOR}")
message(STATUS "===========================================")