# ==============================================================================
# ONNX C Importer Tool
# ==============================================================================

# Tool executable
add_mlir_tool(onnx-c-importer
    SRCS
        onnx-c-importer.cpp
    LIBS
        # Additional tool-specific libraries if needed
        MLIROnnxDialect
        TorchMLIRTorchONNXDialect
        TorchMLIRConversionTorchONNXToTorch
        MLIRFuncDialect
        MLIRArithDialect
        MLIRTensorDialect
        
        # LLVM support libraries
        LLVMSupport
        LLVMCore
        
        # MLIR core libraries
        MLIROptLib
        MLIRExecutionEngine
        MLIRTargetLLVMIRExport
        MLIRLLVMCommonConversion
        MLIRLLVMDialect
)

# Add tool-specific include directories if needed
target_include_directories(onnx-c-importer PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}
    ${CMAKE_CURRENT_BINARY_DIR}
)

# Add any tool-specific compile definitions
target_compile_definitions(onnx-c-importer PRIVATE
    # Tool-specific definitions can go here
)

# Add test subdirectory
add_subdirectory(test)