# ==============================================================================
# ONNX C Importer Tests
# ==============================================================================

# Configure lit configuration for this tool
configure_file(
    ${CMAKE_CURRENT_SOURCE_DIR}/lit.cfg.py.in
    ${CMAKE_CURRENT_BINARY_DIR}/lit.cfg.py
    @ONLY
)

# Add test target for this specific tool
add_custom_target(check-onnx-c-importer
    COMMAND ${LLVM_LIT_PATH} -v ${CMAKE_CURRENT_BINARY_DIR}
    WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}
    COMMENT "Running onnx-c-importer tests"
    USES_TERMINAL
    DEPENDS onnx-c-importer
)

# Make this target part of the global test target
add_dependencies(check-mlir-tools check-onnx-c-importer)
