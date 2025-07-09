# ==============================================================================
# Global Test Configuration for MLIR Tools
# ==============================================================================

# This file sets up the global test infrastructure that can be used
# by individual tool test suites

# Ensure we have the required tools for testing
if(NOT LLVM_LIT_PATH)
    message(WARNING "llvm-lit not found. Global tests will be disabled.")
    return()
endif()

if(NOT FILECHECK_PATH)
    message(WARNING "FileCheck not found. Tests may not work properly.")
endif()

# Set up test configuration variables for lit
set(MLIR_TOOLS_SOURCE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/..)
set(MLIR_TOOLS_BINARY_DIR ${CMAKE_CURRENT_BINARY_DIR}/..)

# Configure the main lit site configuration
configure_file(
    ${CMAKE_CURRENT_SOURCE_DIR}/lit.site.cfg.py.in
    ${CMAKE_CURRENT_BINARY_DIR}/lit.site.cfg.py
    @ONLY
)

# Add a global test target that runs all tool tests
add_custom_target(check-mlir-tools-global
    COMMAND ${LLVM_LIT_PATH} -v ${CMAKE_CURRENT_BINARY_DIR}
    WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}
    COMMENT "Running global mlir-tools tests"
    USES_TERMINAL
)

# Create integration tests directory if it exists
if(EXISTS ${CMAKE_CURRENT_SOURCE_DIR}/integration)
    add_subdirectory(integration)
endif()

# Add any global test files
file(GLOB GLOBAL_TEST_FILES ${CMAKE_CURRENT_SOURCE_DIR}/*.mlir)
if(GLOBAL_TEST_FILES)
    message(STATUS "Found global test files: ${GLOBAL_TEST_FILES}")
endif()

# Set up test dependencies - all tools should be built before running tests
set(TEST_DEPENDS)

# Add tool dependencies if they exist
if(TARGET onnx-c-importer)
    list(APPEND TEST_DEPENDS onnx-c-importer)
endif()

# Add dependencies to the global test target
if(TEST_DEPENDS)
    add_dependencies(check-mlir-tools-global ${TEST_DEPENDS})
endif()

# Make the main check-mlir-tools target depend on this global target
if(TARGET check-mlir-tools)
    add_dependencies(check-mlir-tools check-mlir-tools-global)
endif()

# Export variables for use by individual tool test configurations
set(MLIR_TOOLS_TEST_TOOLS_DIR ${CMAKE_CURRENT_BINARY_DIR}/.. PARENT_SCOPE)
set(MLIR_TOOLS_TEST_SOURCE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/.. PARENT_SCOPE)

message(STATUS "Global test configuration:")
message(STATUS "  Test tools dir: ${CMAKE_CURRENT_BINARY_DIR}/..")
message(STATUS "  LLVM tools dir: ${TORCHMLIR_INSTALL_DIR}/bin")
message(STATUS "  Lit path: ${LLVM_LIT_PATH}")
message(STATUS "  FileCheck path: ${FILECHECK_PATH}")
message(STATUS "  Test dependencies: ${TEST_DEPENDS}")
