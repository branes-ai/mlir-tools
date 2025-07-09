# MLIR Tools Project Structure

This document outlines the structure for adding standalone tools to the mlir-tools project.

## Directory Structure

```
mlir-tools/
├── CMakeLists.txt                    # Main superbuild CMake
├── src/                              # New source directory for tools
│   ├── CMakeLists.txt               # Main src CMakeLists
│   ├── onnx_c_importer/             # Example tool
│   │   ├── CMakeLists.txt
│   │   ├── onnx-c-importer.cpp      # Main tool source
│   │   └── test/                    # Tool-specific tests
│   │       ├── CMakeLists.txt
│   │       └── lit.cfg.py
│   └── common/                      # Shared utilities
│       ├── CMakeLists.txt
│       └── MlirToolsUtils.h
├── test/                            # Global test directory
│   ├── CMakeLists.txt
│   ├── lit.cfg.py
│   └── lit.site.cfg.py.in
├── ext/                             # External dependencies
│   └── torch-mlir/                  # Built by superbuild
└── build/                           # Build artifacts
    ├── src/                         # Tool binaries
    └── ext/                         # External builds
```

## Key Components

### 1. Main CMakeLists.txt Modifications
- Add src directory to the build
- Ensure torch-mlir dependency is built first
- Set up proper target dependencies

### 2. src/CMakeLists.txt
- Configure common includes and libraries
- Add subdirectories for each tool
- Set up testing infrastructure

### 3. Tool-specific CMakeLists.txt
- Link against torch-mlir libraries
- Set up proper include paths
- Configure tool installation

### 4. Testing Setup
- Integrate with torch-mlir's testing infrastructure
- Use LLVM's lit testing framework
- Configure FileCheck for test verification

## Build Process

1. Torch-MLIR is built first (external project)
2. Tools are built using the installed torch-mlir
3. Tests are run using the built tools

This structure provides a clean separation between the external torch-mlir build and your custom tools while maintaining proper dependencies.
