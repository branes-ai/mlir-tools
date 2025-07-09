//===----------------------------------------------------------------------===//
//
// Common utilities for MLIR Tools
//
//===----------------------------------------------------------------------===//

#ifndef MLIR_TOOLS_UTILS_H
#define MLIR_TOOLS_UTILS_H

#include "mlir/IR/BuiltinOps.h"
#include "mlir/IR/MLIRContext.h"
#include "mlir/Support/LogicalResult.h"
#include "llvm/Support/raw_ostream.h"

namespace mlir {
namespace tools {

/// Utility function to setup a standard MLIR context with commonly used dialects
void setupStandardMLIRContext(MLIRContext &context);

/// Utility function to print operation with standard formatting options
void printOperation(Operation *op, llvm::raw_ostream &os, 
                   bool prettyForm = true, bool printGenericOpForm = false);

/// Utility function to verify an operation and print diagnostics if verification fails
LogicalResult verifyAndReportErrors(Operation *op, llvm::raw_ostream &errorOS);

/// Utility function to create a standard pass manager with verification enabled
std::unique_ptr<PassManager> createStandardPassManager(MLIRContext *context, 
                                                       bool enableVerifier = true);

/// Utility function to load and parse an MLIR file
OwningOpRef<ModuleOp> parseMLIRFile(StringRef filename, MLIRContext *context);

/// Utility function to write an MLIR module to a file
LogicalResult writeMLIRFile(ModuleOp module, StringRef filename);

} // namespace tools
} // namespace mlir

#endif // MLIR_TOOLS_UTILS_H
