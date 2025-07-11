cmake_minimum_required(VERSION 3.23)

# ==============================================================================
# Cross-Platform Compiler Detection
# ==============================================================================

# Set compilers to appropriate defaults before project() call
# Only set if not already specified by user

if(NOT CMAKE_C_COMPILER AND NOT CMAKE_CXX_COMPILER)
    if(WIN32)
        # On Windows: Use MSVC (most reliable for torch-mlir)
        message(STATUS "Windows detected: Using MSVC compilers")
        # Don't set CMAKE_C_COMPILER or CMAKE_CXX_COMPILER
        # Let CMake auto-detect MSVC
    else()
        # On Linux/Unix: Use Clang
        message(STATUS "Unix-like system detected: Looking for Clang compilers")
        
        # Find Clang compilers
        find_program(CLANG_C_COMPILER 
            NAMES clang clang-18 clang-17 clang-16 clang-15 clang-14
            DOC "Clang C compiler"
        )
        
        find_program(CLANG_CXX_COMPILER 
            NAMES clang++ clang++-18 clang++-17 clang++-16 clang++-15 clang++-14
            DOC "Clang C++ compiler"
        )
        
        if(CLANG_C_COMPILER AND CLANG_CXX_COMPILER)
            set(CMAKE_C_COMPILER "${CLANG_C_COMPILER}")
            set(CMAKE_CXX_COMPILER "${CLANG_CXX_COMPILER}")
            message(STATUS "Using Clang compilers:")
            message(STATUS "  C: ${CLANG_C_COMPILER}")
            message(STATUS "  C++: ${CLANG_CXX_COMPILER}")
        else()
            message(WARNING "Clang not found on Linux, falling back to default GCC")
            message(STATUS "Missing compilers:")
            if(NOT CLANG_C_COMPILER)
                message(STATUS "  - Clang C compiler not found")
            endif()
            if(NOT CLANG_CXX_COMPILER)
                message(STATUS "  - Clang C++ compiler not found")
            endif()
        endif()
    endif()
else()
    # User specified compilers explicitly
    if(CMAKE_C_COMPILER AND CMAKE_CXX_COMPILER)
        message(STATUS "Using user-specified compilers:")
        message(STATUS "  C: ${CMAKE_C_COMPILER}")
        message(STATUS "  C++: ${CMAKE_CXX_COMPILER}")
    endif()
endif()

project(mlir_tools C CXX)

set(CMAKE_CXX_STANDARD 20 CACHE STRING "v")
set(CMAKE_CXX_STANDARD_REQUIRED True)
set(CMAKE_CXX_EXTENSIONS OFF)
message(STATUS "  C++ standard: ${CMAKE_CXX_STANDARD}")

# ==============================================================================
# Generator Selection Mechanism
# ==============================================================================

# Define a CMake option to select the desired generator.
# Users will set this with -DCMAKE_GENERATOR_IDENTIFIERE=<value> on the CMake command line.
set(CMAKE_GENERATOR_IDENTIFIER "MSVC" CACHE STRING "Select the CMake generator type (MSVC or NINJA)")

message(STATUS "# ========================================================")
message(STATUS "# Generator Selection")
message(STATUS "# ========================================================")

# Determine the actual generator and platform arguments based on GEN_TYPE
if (CMAKE_GENERATOR_IDENTIFIER STREQUAL "MSVC")
    set(SUPERBUILD_CMAKE_GENERATOR "Visual Studio 17 2022")
    set(SUPERBUILD_CMAKE_GENERATOR_PLATFORM "x64")
    set(SUPERBUILD_CMAKE_TOOLSET_ARGS "-T;host=x64") # For MSVC, specify host toolset
    set(SUPERBUILD_PLATFORM_ARGS "-A;${SUPERBUILD_CMAKE_GENERATOR_PLATFORM}")
    message(STATUS "    Configuring for MSVC Generator: ${SUPERBUILD_CMAKE_GENERATOR}")
elseif (CMAKE_GENERATOR_IDENTIFIER STREQUAL "NINJA")
    set(SUPERBUILD_CMAKE_GENERATOR "Ninja")
    set(SUPERBUILD_CMAKE_GENERATOR_PLATFORM "") # Ninja doesn't typically use -A/-T
    set(SUPERBUILD_CMAKE_TOOLSET_ARGS "") # No specific toolset args for Ninja
    set(SUPERBUILD_PLATFORM_ARGS "") # No platform args for Ninja
    message(STATUS "    Configuring for Ninja Generator")
else ()
    message(FATAL_ERROR "    Unsupported CMAKE_GENERATOR_IDENTIFIER: ${CMAKE_GENERATOR_IDENTIFIER}. Please choose MSVC or NINJA.")
endif ()

# ==============================================================================
# Python Environment Configuration (GUI-friendly)
# ==============================================================================
#
# When using the CMake GUI, we need to point to the venv python required
# The python dependencies, pybind11, nanobind, and numpy need to be installed in this venv
# for the build to work.
#
# With Linux this is all dynamically picked up the shell environment.
# When you null this option you'll get the virtual path in the dynamic configuration section
# Example: cmake -DPYTHON_EXECUTABLE="" ..

set(PYTHON_EXECUTABLE "D:/Python/venv/p310/Scripts/python.exe" CACHE FILEPATH "Python executable to use for integration (virtual/specific/system)")

message(STATUS "# ========================================================")
message(STATUS "# Python Environment")
message(STATUS "# ========================================================")

# CRITICAL: Set all Python variables that LLVM/MLIR might use
set(Python3_EXECUTABLE ${PYTHON_EXECUTABLE} CACHE FILEPATH "Python3 executable" FORCE)
set(Python_EXECUTABLE ${PYTHON_EXECUTABLE} CACHE FILEPATH "Python executable" FORCE)

# Find Python using our specified executable to get the right paths
find_package(Python3 REQUIRED COMPONENTS Interpreter Development.Module)

# Verify we're using the right Python
message(STATUS "=== Python Configuration Check ===")
message(STATUS "PYTHON_EXECUTABLE    : ${PYTHON_EXECUTABLE}")
message(STATUS "Python3_EXECUTABLE   : ${Python3_EXECUTABLE}")
message(STATUS "Python3_VERSION      : ${Python3_VERSION}")
message(STATUS "Python3_INCLUDE_DIRS : ${Python3_INCLUDE_DIRS}")
message(STATUS "Python3_LIBRARIES    : ${Python3_LIBRARIES}")
message(STATUS "===================================")

# Force all subsequent find_package(Python3) calls to use our executable
set(Python3_FIND_REGISTRY "NEVER" CACHE STRING "Never use registry to find Python3")
set(Python3_FIND_FRAMEWORK "NEVER" CACHE STRING "Never use framework to find Python3")

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

# ==============================================================================
# LLVM/MLIR: Build Directly with Its Own CMake
# ==============================================================================

message(STATUS "# ========================================================")
message(STATUS "# LLVM/MLIR Configuration")
message(STATUS "# ========================================================")

# LLVM Configuration
set(LLVM_ENABLE_PROJECTS "mlir" CACHE STRING "LLVM projects to build")
set(LLVM_TARGETS_TO_BUILD "host" CACHE STRING "LLVM targets")
set(CMAKE_BUILD_TYPE "Release" CACHE STRING "Build type")
set(LLVM_ENABLE_ASSERTIONS ON CACHE BOOL "Enable assertions")
set(MLIR_ENABLE_BINDINGS_PYTHON ON CACHE BOOL "Enable Python bindings")

# Windows-specific optimizations
if(WIN32)
    set(LLVM_USE_CRT_RELEASE MD CACHE STRING "CRT for release builds")
    set(LLVM_ENABLE_PDB OFF CACHE BOOL "Enable PDB")
    set(LLVM_BUILD_EXAMPLES OFF CACHE BOOL "Build examples")
    set(LLVM_BUILD_TESTS OFF CACHE BOOL "Build tests")
    set(LLVM_INCLUDE_TESTS OFF CACHE BOOL "Include tests")
    set(LLVM_ENABLE_TERMINFO OFF CACHE BOOL "Enable terminfo")
    set(LLVM_ENABLE_LIBEDIT OFF CACHE BOOL "Enable libedit")
    set(LLVM_ENABLE_LIBXML2 OFF CACHE BOOL "Enable libxml2")
    set(LLVM_ENABLE_ZLIB OFF CACHE BOOL "Enable zlib")
    set(LLVM_ENABLE_ZSTD OFF CACHE BOOL "Enable zstd")
endif()

# These pooling options only work with Ninja, skip them for Visual Studio
if(CMAKE_GENERATOR_IDENTIFIER MATCHES "NINJA")
    set(LLVM_PARALLEL_COMPILE_JOBS 1 CACHE STRING "Parallel compile jobs")
    set(LLVM_PARALLEL_LINK_JOBS 1 CACHE STRING "Parallel link jobs")
endif()

# Set Python for torch-mlir - use the same variables LLVM expects
#set(Python3_EXECUTABLE ${PYTHON_EXECUTABLE} CACHE FILEPATH "Python3 executable" FORCE)
#set(Python_EXECUTABLE ${PYTHON_EXECUTABLE} CACHE FILEPATH "Python executable" FORCE)

# Also set the include dirs and libraries from our Python search
#if(Python3_INCLUDE_DIRS)
#    set(Python3_INCLUDE_DIRS ${Python3_INCLUDE_DIRS} CACHE PATH "Python3 include dirs" FORCE)
#endif()
#if(Python3_LIBRARIES)
#    set(Python3_LIBRARIES ${Python3_LIBRARIES} CACHE FILEPATH "Python3 libraries" FORCE)
#endif()

# Set up torch-mlir as LLVM external project BEFORE calling llvm-project
set(LLVM_EXTERNAL_PROJECTS "torch-mlir" CACHE STRING "External projects")
set(LLVM_EXTERNAL_TORCH_MLIR_SOURCE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/ext/torch-mlir CACHE PATH "Torch-MLIR source")

# Include LLVM's main CMakeLists.txt from the torch-mlir submodule
add_subdirectory(${CMAKE_CURRENT_SOURCE_DIR}/ext/torch-mlir/externals/llvm-project/llvm)

# ==============================================================================
# Custom function to add tools after LLVM is configured
# ==============================================================================

# Function to create tools that link against torch-mlir
function(add_torch_mlir_tool tool_name)
    cmake_parse_arguments(ARG "" "" "SRCS" ${ARGN})
    
    add_llvm_executable(${tool_name} ${ARG_SRCS})
    
    target_link_libraries(${tool_name} PRIVATE
        # Core MLIR
        MLIRIR
        MLIRParser
        MLIRPass
        MLIRSupport
        MLIRTransforms
        MLIRFuncDialect
        
        # Torch-MLIR (these targets should be available after LLVM build)
        TorchMLIRTorchDialect
        TorchMLIRTorchONNXDialect
        TorchMLIRConversionTorchONNXToTorch
        
        # LLVM
        LLVMSupport
        LLVMCore
    )
    
    # Install the tool
    install(TARGETS ${tool_name} DESTINATION bin)
endfunction()

# ==============================================================================
# Add Your Tools Here
# ==============================================================================

message(STATUS "# ========================================================")
message(STATUS "# MLIR-tools Configuration")
message(STATUS "# ========================================================")

# Add the onnx-c-importer tool
add_torch_mlir_tool(onnx-c-importer
    SRCS src/onnx_c_importer/onnx_c_importer.cpp
)

# Add more tools as needed
# add_torch_mlir_tool(another-tool SRCS src/another_tool/main.cpp)

message(STATUS "")
message(STATUS "# ========================================================")
message(STATUS "# Torch-MLIR Build Configuration")
message(STATUS "# ========================================================")
message(STATUS "")
message(STATUS "Building LLVM with torch-mlir as external project")
message(STATUS "Torch-MLIR source   : ${LLVM_EXTERNAL_TORCH_MLIR_SOURCE_DIR}")
message(STATUS "Python executable   : ${PYTHON_EXECUTABLE}")
message(STATUS "Custom Tools source : ${CMAKE_SOURCE_DIR}/src")
message(STATUS "Final tools install : ${CMAKE_BINARY_DIR}/install")
message(STATUS "")
message(STATUS "# ========================================================")
