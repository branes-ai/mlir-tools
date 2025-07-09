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
# Smart Build Caching and Resource Management
# ==============================================================================

# Option to skip torch-mlir rebuild if it's already built
option(SKIP_TORCHMLIR_BUILD "Skip torch-mlir build if already present" ON)

# Option to use pre-built torch-mlir from a specific directory
set(PREBUILT_TORCHMLIR_DIR "" CACHE PATH "Path to pre-built torch-mlir installation")

# Option to enable ccache for faster rebuilds
option(USE_CCACHE "Use ccache for faster compilation" ON)

# Resource constraint options for Windows builds
set(LLVM_PARALLEL_COMPILE_JOBS "1" CACHE STRING "Number of parallel compile jobs for LLVM")
set(LLVM_PARALLEL_LINK_JOBS "1" CACHE STRING "Number of parallel link jobs for LLVM")

# CCache Configuration
if(USE_CCACHE AND NOT WIN32)  # ccache is less reliable on Windows
    find_program(CCACHE_PROGRAM ccache)
    if(CCACHE_PROGRAM)
        message(STATUS "Found ccache: ${CCACHE_PROGRAM}")
        set(CMAKE_C_COMPILER_LAUNCHER "${CCACHE_PROGRAM}")
        set(CMAKE_CXX_COMPILER_LAUNCHER "${CCACHE_PROGRAM}")
    endif()
endif()

# ==============================================================================
# Smart Rebuild Detection
# ==============================================================================

# Check if torch-mlir is already properly built
set(TORCHMLIR_NEEDS_BUILD TRUE)

if(SKIP_TORCHMLIR_BUILD OR PREBUILT_TORCHMLIR_DIR)
    if(PREBUILT_TORCHMLIR_DIR)
        get_filename_component(TORCHMLIR_INSTALL_DIR "${PREBUILT_TORCHMLIR_DIR}" ABSOLUTE)
        message(STATUS "Using pre-built torch-mlir from: ${TORCHMLIR_INSTALL_DIR}")
    endif()
    
    # Check if key files exist
    set(KEY_FILES
        "${TORCHMLIR_INSTALL_DIR}/bin/torch-mlir-opt${CMAKE_EXECUTABLE_SUFFIX}"
        "${TORCHMLIR_INSTALL_DIR}/lib/cmake/torch-mlir/TorchMLIRConfig.cmake"
    )
    
    set(ALL_FILES_EXIST TRUE)
    foreach(FILE ${KEY_FILES})
        if(NOT EXISTS "${FILE}")
            set(ALL_FILES_EXIST FALSE)
            message(STATUS "Missing torch-mlir file: ${FILE}")
            break()
        endif()
    endforeach()
    
    if(ALL_FILES_EXIST)
        set(TORCHMLIR_NEEDS_BUILD FALSE)
        message(STATUS "Torch-MLIR is available, skipping rebuild")
    else()
        message(STATUS "Torch-MLIR not found or incomplete, will build")
    endif()
endif()

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
#ExternalProject_Add(torch-mlir
#    SOURCE_DIR ${TORCHMLIR_SOURCE_DIR}/externals/llvm-project/llvm
#    BINARY_DIR ${TORCHMLIR_BINARY_DIR}
#    
    # Update submodules first
#    UPDATE_COMMAND ""
#    PATCH_COMMAND ${CMAKE_COMMAND} -E chdir ${TORCHMLIR_SOURCE_DIR} 
#                  git submodule update --init --recursive
#                  COMMAND ${CMAKE_COMMAND} -E remove_directory ${TORCHMLIR_BINARY_DIR}
#                  COMMAND ${CMAKE_COMMAND} -E make_directory ${TORCHMLIR_BINARY_DIR}
    
    # Configure LLVM with torch-mlir as external project
#    CMAKE_GENERATOR ${SUPERBUILD_CMAKE_GENERATOR}
#    CMAKE_GENERATOR_PLATFORM ${SUPERBUILD_CMAKE_GENERATOR_PLATFORM}
#    CMAKE_ARGS ${TORCHMLIR_CMAKE_ARGS}
    
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
    # reenabling the install command but this time with a small resource constraint

    # Log output for debugging
#    LOG_CONFIGURE ON
#    LOG_BUILD ON
#    LOG_INSTALL ON
#)

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

# Build torch-mlir only if needed
if(TORCHMLIR_NEEDS_BUILD)
    message(STATUS "Building torch-mlir (this may take a while)...")
    
    # More conservative resource settings for Windows
    if(WIN32)
        set(LLVM_PARALLEL_COMPILE_JOBS "1")
        set(LLVM_PARALLEL_LINK_JOBS "1")
    endif()
    
    list(APPEND TORCHMLIR_CMAKE_ARGS
        "-DLLVM_PARALLEL_COMPILE_JOBS=${LLVM_PARALLEL_COMPILE_JOBS}"
        "-DLLVM_PARALLEL_LINK_JOBS=${LLVM_PARALLEL_LINK_JOBS}"
        
        # Additional memory/resource optimizations
        "-DLLVM_USE_SPLIT_DWARF=OFF"  # Reduces memory usage
        "-DLLVM_ENABLE_PDB=OFF"       # Reduces disk I/O on Windows
        "-DLLVM_BUILD_EXAMPLES=OFF"   # Skip examples
        "-DLLVM_BUILD_TESTS=OFF"      # Skip LLVM tests initially
        "-DLLVM_INCLUDE_TESTS=OFF"    # Don't include test targets
    )

    # Add ccache if available and not Windows
    if(CCACHE_PROGRAM AND NOT WIN32)
        list(APPEND TORCHMLIR_CMAKE_ARGS
            "-DCMAKE_C_COMPILER_LAUNCHER=${CCACHE_PROGRAM}"
            "-DCMAKE_CXX_COMPILER_LAUNCHER=${CCACHE_PROGRAM}"
        )
    endif()

    ExternalProject_Add(torch-mlir
        SOURCE_DIR ${TORCHMLIR_SOURCE_DIR}/externals/llvm-project/llvm
        BINARY_DIR ${TORCHMLIR_BINARY_DIR}
        
        UPDATE_COMMAND ""
        PATCH_COMMAND ${CMAKE_COMMAND} -E chdir ${TORCHMLIR_SOURCE_DIR} 
                      git submodule update --init --recursive
                      COMMAND ${CMAKE_COMMAND} -E remove_directory ${TORCHMLIR_BINARY_DIR}
                      COMMAND ${CMAKE_COMMAND} -E make_directory ${TORCHMLIR_BINARY_DIR}
        
        CMAKE_GENERATOR ${SUPERBUILD_CMAKE_GENERATOR}
        CMAKE_GENERATOR_PLATFORM ${SUPERBUILD_CMAKE_GENERATOR_PLATFORM}
        CMAKE_ARGS ${TORCHMLIR_CMAKE_ARGS}
        
        # More conservative build command for Windows
        BUILD_COMMAND ${CMAKE_COMMAND} --build <BINARY_DIR> --config Release --target torch-mlir-opt TorchMLIRPythonModules --parallel ${LLVM_PARALLEL_COMPILE_JOBS}
        INSTALL_COMMAND ${CMAKE_COMMAND} --build <BINARY_DIR> --config Release --target install --parallel ${LLVM_PARALLEL_LINK_JOBS}
        
        # Only build when actually needed
        BUILD_ALWAYS FALSE
        
        LOG_CONFIGURE ON
        LOG_BUILD ON
        LOG_INSTALL ON
    )
    
    set(TORCHMLIR_TARGET torch-mlir)
else()
    message(STATUS "Using existing torch-mlir installation: ${TORCHMLIR_INSTALL_DIR}")
    
    # Create a dummy target for consistency
    add_custom_target(torch-mlir
        COMMAND ${CMAKE_COMMAND} -E echo "Using pre-built torch-mlir from ${TORCHMLIR_INSTALL_DIR}"
        COMMENT "Torch-MLIR already available"
    )
    
    set(TORCHMLIR_TARGET torch-mlir)
endif()


# ==============================================================================
# MLIR Tools Source Directory
# ==============================================================================

# Enable building the tools after torch-mlir is installed
option(BUILD_MLIR_TOOLS "Build the mlir-tools source directory" ON)

if(BUILD_MLIR_TOOLS)
    # Add the src directory as an external project that depends on torch-mlir
    ExternalProject_Add(mlir-tools-src
        SOURCE_DIR ${CMAKE_SOURCE_DIR}/src
        BINARY_DIR ${CMAKE_BINARY_DIR}/src
        
        # No download/update needed - it's local source
        DOWNLOAD_COMMAND ""
        UPDATE_COMMAND ""
        PATCH_COMMAND ""
        
        # Configure after torch-mlir is built
        CMAKE_GENERATOR ${SUPERBUILD_CMAKE_GENERATOR}
        CMAKE_GENERATOR_PLATFORM ${SUPERBUILD_CMAKE_GENERATOR_PLATFORM}
        CMAKE_ARGS
            "-DCMAKE_BUILD_TYPE=Release"
            "-DCMAKE_C_COMPILER=clang"
            "-DCMAKE_CXX_COMPILER=clang++"
            "-DTORCHMLIR_INSTALL_DIR=${TORCHMLIR_INSTALL_DIR_CMAKE}"
            "-DPython3_EXECUTABLE=${PYTHON_EXECUTABLE_CMAKE}"
            "-DCMAKE_INSTALL_PREFIX=${CMAKE_BINARY_DIR}/install"
            
        # Depend on torch-mlir being built first
        DEPENDS torch-mlir
        
        # Build and install
        BUILD_COMMAND ${CMAKE_COMMAND} --build <BINARY_DIR> --config Release --parallel 2
        INSTALL_COMMAND ${CMAKE_COMMAND} --build <BINARY_DIR> --config Release --target install
        
        # Log output
        LOG_CONFIGURE ON
        LOG_BUILD ON
        LOG_INSTALL ON
    )
    
    # Create a convenient alias target
    add_custom_target(tools DEPENDS mlir-tools-src)
endif()


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
message(STATUS "Building torch-mlir as LLVM external project")
if(BUILD_MLIR_TOOLS)
    message(STATUS "Building mlir-tools source directory: ${CMAKE_SOURCE_DIR}/src")
    message(STATUS "Tools install directory: ${CMAKE_BINARY_DIR}/install")
endif()
message(STATUS "===========================================")
