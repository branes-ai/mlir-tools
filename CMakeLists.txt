cmake_minimum_required(VERSION 3.31)
project(mlir_tools_superbuild C CXX)

include(ExternalProject)

# === LLVM Configuration ===
set(LLVM_SOURCE_DIR ${CMAKE_SOURCE_DIR}/ext/llvm-project/llvm)
set(LLVM_BINARY_DIR ${CMAKE_BINARY_DIR}/ext/llvm-build)
set(LLVM_INSTALL_DIR ${CMAKE_BINARY_DIR}/ext/llvm-install)

ExternalProject_Add(llvm-project
  SOURCE_DIR ${LLVM_SOURCE_DIR}
  BINARY_DIR ${LLVM_BINARY_DIR}
  CMAKE_ARGS
    -DCMAKE_INSTALL_PREFIX=${LLVM_INSTALL_DIR}
    -DLLVM_ENABLE_PROJECTS=mlir
    -DLLVM_TARGETS_TO_BUILD=host
    -DCMAKE_BUILD_TYPE=Release
    -DCMAKE_GENERATOR_PLATFORM=x64
    -DLLVM_ENABLE_ASSERTIONS=ON
    -T host=x64
#   -G "Visual Studio 17 2022"
  INSTALL_DIR ${LLVM_INSTALL_DIR}
  INSTALL_COMMAND cmake --build . --target INSTALL --config Release
)

# === Torch-MLIR Configuration ===
# === LLVM Configuration ===
set(TORCHMLIR_SOURCE_DIR ${CMAKE_SOURCE_DIR}/ext/torch-mlir)
set(TORCHMLIR_BINARY_DIR ${CMAKE_BINARY_DIR}/ext/torch-mlir-build)
set(TORCHMLIR_INSTALL_DIR ${CMAKE_BINARY_DIR}/ext/torch-mlir-install)

ExternalProject_Add(torch-mlir
  SOURCE_DIR ${TORCHMLIR_SOURCE_DIR}
  BINARY_DIR ${TORCHMLIR_BINARY_DIR}
  CMAKE_ARGS
    -DCMAKE_PREFIX_PATH=${TORCHMLIR_INSTALL_DIR}
    -DMLIR_DIR=${LLVM_INSTALL_DIR}/lib/cmake/mlir
    -DLLVM_DIR=${LLVM_INSTALL_DIR}/lib/cmake/llvm
    -DCMAKE_BUILD_TYPE=Release
    -DLLVM_ENABLE_ASSERTIONS=ON
    -DLLVM_EXTERNAL_PROJECTS="torch-mlir"
    -DLLVM_EXTERNAL_TORCH_MLIR_SOURCE_DIR=${TORCHMLIR_SOURCE_DIR}
#    -G "Visual Studio 17 2022"
    -T host=x64
  DEPENDS llvm-project
)
