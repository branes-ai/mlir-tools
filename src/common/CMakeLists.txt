# ==============================================================================
# Common Utilities for MLIR Tools
# ==============================================================================

# Create a header-only library for common utilities
add_library(MlirToolsCommon INTERFACE)

# Add include directories
target_include_directories(MlirToolsCommon INTERFACE
    ${CMAKE_CURRENT_SOURCE_DIR}
)

# Link against common MLIR libraries that all tools will need
target_link_libraries(MlirToolsCommon INTERFACE
    MLIRIR
    MLIRSupport
    MLIRParser
    LLVMSupport
)

# Install headers
install(FILES
    MlirToolsUtils.h
    DESTINATION include/mlir-tools/common
)
