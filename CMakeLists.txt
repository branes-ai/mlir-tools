cmake_minimum_required(VERSION 3.23)

# Set compilers before project() call - must be done BEFORE project()
# This will only set if not already set by environment or command line
if(NOT DEFINED CMAKE_C_COMPILER)
    find_program(CLANG_C_COMPILER clang)
    if(CLANG_C_COMPILER)
        set(CMAKE_C_COMPILER ${CLANG_C_COMPILER})
    else()
        message(WARNING "clang not found, falling back to default C compiler")
    endif()
endif()

if(NOT DEFINED CMAKE_CXX_COMPILER)
    find_program(CLANG_CXX_COMPILER clang++)
    if(CLANG_CXX_COMPILER)
        set(CMAKE_CXX_COMPILER ${CLANG_CXX_COMPILER})
    else()
        message(WARNING "clang++ not found, falling back to default C++ compiler")
    endif()
endif()

project(mlir_tools_superbuild C CXX)


# When using the CMake GUI, we need to point to the venv python required
# The python dependencies, pybind11, nanobind, and numpy need to be installed in this venv
# for the build to work.
# With Linux this is all dynamically picked up the shell environment.
# You can null this option to get the virtual path in the dynamic configuration section
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
#
#
# Usage Linux
#
# create a virtual environment of your choice
#   python3.10 -m venv ~/venv/p310
# activate the virtual environment
#   source ~/venv/p310/bin/activate
#
# install the python dependencies
#    python -m pip install pybind11 nanobind numpy
#
# generate the build files
#    cmake -DCMAKE_GENERATOR_IDENTIFIER=NINJA -DPYTHON_EXECUTABLE="" ..
#-- Virtual environment detected: /home/stillwater/venv/p310
#-- Using virtual environment Python: /home/stillwater/venv/p310/bin/python
#-- Using Python: /home/stillwater/venv/p310/bin/python
#-- Python version: 3.10
#-- Python include dir: /usr/include/python3.10
#-- Pybind11 installed: Python: /home/stillwater/venv/p310/bin/python
#pybind11: 2.13.6
#
#-- Nanobind installed: Python: /home/stillwater/venv/p310/bin/python
#nanobind: 2.7.0
#
#-- Configuring for Ninja Generator
#-- ==== Torch-MLIR Configuration Summary ====
#-- Source directory: /home/stillwater/dev/clones/mlir-tools/ext/torch-mlir
#-- Binary directory: /home/stillwater/dev/clones/mlir-tools/build_clang/ext/torch-mlir-build
#-- Install directory: /home/stillwater/dev/clones/mlir-tools/build_clang/ext/torch-mlir-install
#-- Python executable: /home/stillwater/venv/p310/bin/python
#-- Python version: 3.10
#-- Generator: Ninja
#-- Building torch-mlir as LLVM external project
#-- ===========================================
#-- Configuring done
#-- Generating done
#-- Build files have been written to: /home/stillwater/dev/clones/mlir-tools/build_clang

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
# Torch-MLIR Configuration (using LLVM External Project approach)
# ==============================================================================
set(TORCHMLIR_SOURCE_DIR ${CMAKE_SOURCE_DIR}/ext/torch-mlir)
set(TORCHMLIR_BINARY_DIR ${CMAKE_BINARY_DIR}/ext/torch-mlir-build)
set(TORCHMLIR_INSTALL_DIR ${CMAKE_BINARY_DIR}/ext/torch-mlir-install)

# Convert paths to use forward slashes for CMake
file(TO_CMAKE_PATH "${TORCHMLIR_INSTALL_DIR}" TORCHMLIR_INSTALL_DIR_CMAKE)
file(TO_CMAKE_PATH "${PYTHON_EXECUTABLE}" PYTHON_EXECUTABLE_CMAKE)
file(TO_CMAKE_PATH "${PYTHON_INCLUDE_DIR}" PYTHON_INCLUDE_DIR_CMAKE)
file(TO_CMAKE_PATH "${TORCHMLIR_SOURCE_DIR}" TORCHMLIR_SOURCE_DIR_CMAKE)

# Build torch-mlir as an LLVM external project
# This is the correct approach - torch-mlir builds LLVM/MLIR from its submodules
# and registers itself as an external project
set(TORCHMLIR_CMAKE_ARGS
    "-DCMAKE_INSTALL_PREFIX=${TORCHMLIR_INSTALL_DIR_CMAKE}"
    "-DCMAKE_BUILD_TYPE=Release"
    
    # Python configuration
    "-DPython3_EXECUTABLE=${PYTHON_EXECUTABLE_CMAKE}"
    
    # Compiler configuration
    "-DCMAKE_C_COMPILER=clang"
    "-DCMAKE_CXX_COMPILER=clang++"
    
    # LLVM configuration - torch-mlir builds LLVM from its submodule
    "-DLLVM_ENABLE_PROJECTS=mlir"
    "-DLLVM_EXTERNAL_PROJECTS=torch-mlir"
    "-DLLVM_EXTERNAL_TORCH_MLIR_SOURCE_DIR=${TORCHMLIR_SOURCE_DIR_CMAKE}"
    
    # Enable Python bindings
    "-DMLIR_ENABLE_BINDINGS_PYTHON=ON"
    
    # LLVM optimizations- cross-platform
    "-DLLVM_ENABLE_ASSERTIONS=ON"
    "-DLLVM_TARGETS_TO_BUILD=host"
)

# Add platform-specific optimizations
if(WIN32)
    list(APPEND TORCHMLIR_CMAKE_ARGS
        "-DLLVM_USE_CRT_RELEASE=MD"
        "-DLLVM_ENABLE_PDB=OFF"
        "-DLLVM_PARALLEL_COMPILE_JOBS=2"
        "-DLLVM_PARALLEL_LINK_JOBS=1"
    )
else()
    # On Linux, let Ninja handle parallelism automatically
    # Don't set LLVM_PARALLEL_*_JOBS as they conflict with Ninja pools
    list(APPEND TORCHMLIR_CMAKE_ARGS
        "-DLLVM_ENABLE_LIBEDIT=OFF"
        "-DLLVM_ENABLE_LIBXML2=OFF"
        "-DLLVM_ENABLE_ZLIB=OFF"
        "-DLLVM_ENABLE_ZSTD=OFF"
    )
endif()


# Update torch-mlir submodules and configure as LLVM external project
ExternalProject_Add(torch-mlir
    SOURCE_DIR ${TORCHMLIR_SOURCE_DIR}/externals/llvm-project/llvm
    BINARY_DIR ${TORCHMLIR_BINARY_DIR}
    
    # Update submodules first
    UPDATE_COMMAND ""
    PATCH_COMMAND ${CMAKE_COMMAND} -E chdir ${TORCHMLIR_SOURCE_DIR} 
                  git submodule update --init --recursive
                  COMMAND ${CMAKE_COMMAND} -E remove_directory ${TORCHMLIR_BINARY_DIR}
                  COMMAND ${CMAKE_COMMAND} -E make_directory ${TORCHMLIR_BINARY_DIR}
    
    # Configure LLVM with torch-mlir as external project
    CMAKE_GENERATOR ${SUPERBUILD_CMAKE_GENERATOR}
    CMAKE_GENERATOR_PLATFORM ${SUPERBUILD_CMAKE_GENERATOR_PLATFORM}
    CMAKE_ARGS ${TORCHMLIR_CMAKE_ARGS}
    
    # Build and install
    #BUILD_COMMAND ${CMAKE_COMMAND} --build <BINARY_DIR> --config Release
    #INSTALL_COMMAND ${CMAKE_COMMAND} --build <BINARY_DIR> --config Release --target install
    # this failed without an err log, indicating with high probability that we ran into resource constraints

    # Build and install with more specific targeting and verbose output
    #BUILD_COMMAND ${CMAKE_COMMAND} --build <BINARY_DIR> --config Release --target torch-mlir-opt --parallel 2 --verbose
    #INSTALL_COMMAND ""
    # this produced a successful build in about 45min
    
    # Build and install with more specific targeting and verbose output
    BUILD_COMMAND ${CMAKE_COMMAND} --build <BINARY_DIR> --config Release --target torch-mlir-opt TorchMLIRPythonModules --parallel 2
    INSTALL_COMMAND ${CMAKE_COMMAND} --build <BINARY_DIR> --config Release --target install --parallel 1
    # reenabling the install command but this time with a little resource constraint

    # Log output for debugging
    LOG_CONFIGURE ON
    LOG_BUILD ON
    LOG_INSTALL ON
)

# ==============================================================================
# Now when you build this, you should get:
#
#   torch-mlir-opt: The main torch-mlir optimizer tool
#   Python bindings: So you can use torch-mlir from Python
#   Proper installation: Everything installed to D:/build/mlir-tools/build_msvc/ext/torch-mlir-install
#
# The installed directory should contain:
#
#   bin/torch-mlir-opt.exe - The main tool
#   lib/ - Libraries for linking against torch-mlir
#   include/ - Headers for C++ development
#   python_packages/torch_mlir/ - Python module
#
# This gives you a complete, usable torch-mlir installation that you can use 
# for your MLIR development work. 
# The conservative build settings ensure it should build reliably on your Windows 
# system without running into resource exhaustion issues.
#
# ==============================================================================

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
message(STATUS "Building torch-mlir as LLVM external project")
message(STATUS "===========================================")
