# MLIR Tools Setup Instructions

This document provides step-by-step instructions for setting up the `onnx_c_importer` tool and the general MLIR tools infrastructure.

## Directory Structure to Create

Create the following directory structure in your `mlir-tools` project:

```
mlir-tools/
├── CMakeLists.txt                           # Update with the new content
├── src/                                     # New directory
│   ├── CMakeLists.txt                      # Main src build configuration
│   ├── common/                             # Common utilities
│   │   ├── CMakeLists.txt
│   │   └── MlirToolsUtils.h
│   ├── onnx_c_importer/                    # ONNX C Importer tool
│   │   ├── CMakeLists.txt
│   │   ├── onnx-c-importer.cpp
│   │   └── test/
│   │       ├── CMakeLists.txt
│   │       ├── lit.cfg.py.in
│   │       └── basic_import.mlir
│   └── test/                               # Global test configuration
│       ├── CMakeLists.txt
│       ├── lit.cfg.py
│       └── lit.site.cfg.py.in
└── ext/                                    # Existing external deps
    └── torch-mlir/
```

## Setup Steps

### 1. Update the Main CMakeLists.txt

Replace your existing `CMakeLists.txt` with the updated version that includes support for building the `src` directory after torch-mlir is built.

### 2. Create Source Directory Structure

Create the `src` directory and all its subdirectories as shown in the structure above.

### 3. Copy Files

Copy all the provided CMakeLists.txt files, source files, and test configurations to their respective locations.

### 4. Build Process

The build process will now work as follows:

1. **Torch-MLIR Build**: First, torch-mlir is built as an external project (as before)
2. **Tools Build**: After torch-mlir is installed, the src directory is built as a separate external project
3. **Tool Installation**: The tools are installed to `build/install/bin/`

### 5. Build Commands

```bash
# Configure (same as before)
cmake -DCMAKE_GENERATOR_IDENTIFIER=NINJA -DPYTHON_EXECUTABLE="" ..

# Build torch-mlir only
cmake --build . --target torch-mlir

# Build tools (depends on torch-mlir)
cmake --build . --target tools

# Build everything
cmake --build .

# Run tests
cmake --build . --target check-mlir-tools
```

## Using the ONNX C Importer

Once built, you can use the `onnx-c-importer` tool:

```bash
# Basic usage
./build/install/bin/onnx-c-importer input.mlir -o output.mlir

# With ONNX to Torch conversion
./build/install/bin/onnx-c-importer input.mlir --convert-onnx-to-torch -o output.mlir

# Show available dialects
./build/install/bin/onnx-c-importer --show-dialects

# Run with verification
./build/install/bin/onnx-c-importer input.mlir --verify-each -o output.mlir
```

## Adding New Tools

To add a new tool, follow this pattern:

1. **Create tool directory**: `src/your_new_tool/`
2. **Add CMakeLists.txt**: Use the `add_mlir_tool()` function
3. **Add source files**: Implement your tool using the common utilities
4. **Add tests**: Create a `test/` subdirectory with lit tests
5. **Update src/CMakeLists.txt**: Add `add_subdirectory(your_new_tool)`

## Key Features

### Modern C++ Support
- Uses C++17 standard (aligned with LLVM/MLIR)
- Leverages modern C++ idioms and standard library features
- Clean separation between tool logic and MLIR infrastructure

### Proper Dependency Management
- Tools are built after torch-mlir is fully installed
- Proper linking against torch-mlir libraries
- Clean include path management

### Testing Infrastructure
- Integrated with LLVM's lit testing framework
- FileCheck-based test verification
- Tool-specific and global test targets

### Extensible Design
- Common utilities for shared functionality
- Consistent tool structure across the project
- Easy to add new tools following the established pattern

## Troubleshooting

### Common Issues

1. **Missing torch-mlir libraries**: Ensure torch-mlir builds successfully first
2. **Python path issues**: Make sure the same Python executable is used throughout
3. **Test failures**: Verify that `FileCheck` and `llvm-lit` are available in the torch-mlir installation

### Debug Build

For debugging, you can build with debug information:

```bash
cmake -DCMAKE_BUILD_TYPE=Debug -DCMAKE_GENERATOR_IDENTIFIER=NINJA ..
```

This structure provides a solid foundation for building MLIR tools on top of torch-mlir while maintaining clean separation of concerns and following modern C++ practices.
