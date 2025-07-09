//===----------------------------------------------------------------------===//
//
// ONNX C Importer Tool
//
// This tool provides a command-line interface for importing ONNX models
// and converting them to Torch-MLIR representations.
//
//===----------------------------------------------------------------------===//

#include "mlir/Dialect/Func/IR/FuncOps.h"
#include "mlir/IR/AsmState.h"
#include "mlir/IR/BuiltinOps.h"
#include "mlir/IR/MLIRContext.h"
#include "mlir/InitAllDialects.h"
#include "mlir/InitAllPasses.h"
#include "mlir/Pass/Pass.h"
#include "mlir/Pass/PassManager.h"
#include "mlir/Support/FileUtilities.h"
#include "mlir/Support/ToolUtilities.h"
#include "mlir/Tools/mlir-opt/MlirOptMain.h"

#include "torch-mlir/Dialect/Torch/IR/TorchDialect.h"
#include "torch-mlir/Dialect/TorchConversion/IR/TorchConversionDialect.h"
#include "torch-mlir/Conversion/TorchOnnxToTorch/TorchOnnxToTorch.h"

#include "llvm/Support/CommandLine.h"
#include "llvm/Support/InitLLVM.h"
#include "llvm/Support/SourceMgr.h"
#include "llvm/Support/ToolOutputFile.h"

using namespace mlir;
using namespace llvm;

// Command line options
static cl::opt<std::string> inputFilename(cl::Positional,
                                          cl::desc("<input onnx file>"),
                                          cl::init("-"));

static cl::opt<std::string> outputFilename("o", cl::desc("Output filename"),
                                           cl::value_desc("filename"),
                                           cl::init("-"));

static cl::opt<bool> splitInputFile("split-input-file",
                                    cl::desc("Split the input file into pieces and process each chunk independently"),
                                    cl::init(false));

static cl::opt<bool> verifyDiagnostics("verify-diagnostics",
                                       cl::desc("Check that emitted diagnostics match expected-* lines on the corresponding line"),
                                       cl::init(false));

static cl::opt<bool> verifyPasses("verify-each",
                                  cl::desc("Run the verifier after each transformation pass"),
                                  cl::init(true));

static cl::opt<bool> allowUnregisteredDialects("allow-unregistered-dialect",
                                                cl::desc("Allow operation with no registered dialects"),
                                                cl::init(false));

static cl::opt<bool> showDialects("show-dialects",
                                  cl::desc("Print the list of registered dialects"),
                                  cl::init(false));

// Pass pipeline options
static cl::opt<bool> convertOnnxToTorch("convert-onnx-to-torch",
                                        cl::desc("Run ONNX to Torch dialect conversion"),
                                        cl::init(false));

static cl::opt<bool> torchBackendLowering("torch-backend-lowering",
                                          cl::desc("Run full Torch backend lowering pipeline"),
                                          cl::init(false));

namespace {

/// Register all the dialects and passes we might need
void registerAllRequiredDialects(DialectRegistry &registry) {
  // Register core MLIR dialects
  registerAllDialects(registry);
  
  // Register Torch-MLIR dialects
  registry.insert<torch::TorchDialect>();
  registry.insert<torch::TorchConversionDialect>();
}

/// Build the pass pipeline based on command line options
void buildPassPipeline(PassManager &pm) {
  if (convertOnnxToTorch) {
    // Add ONNX to Torch conversion pass
    pm.addPass(createConvertTorchOnnxToTorchPass());
  }
  
  if (torchBackendLowering) {
    // Add full backend lowering pipeline
    // This would include additional passes for complete lowering
    // For now, we'll just add the ONNX conversion
    pm.addPass(createConvertTorchOnnxToTorchPass());
    
    // Additional passes could be added here for complete lowering:
    // - Shape inference
    // - Backend contract
    // - Linalg lowering
    // etc.
  }
}

/// Main processing function
LogicalResult processFile(MLIRContext &context, 
                         StringRef inputFilename, 
                         StringRef outputFilename) {
  // Set up input file
  std::string errorMessage;
  auto file = openInputFile(inputFilename, &errorMessage);
  if (!file) {
    llvm::errs() << errorMessage << "\n";
    return failure();
  }

  // Set up output file
  auto output = openOutputFile(outputFilename, &errorMessage);
  if (!output) {
    llvm::errs() << errorMessage << "\n";
    return failure();
  }

  // Parse the input
  SourceMgr sourceMgr;
  sourceMgr.AddNewSourceBuffer(std::move(file), SMLoc());
  
  OwningOpRef<Operation *> op;
  if (splitInputFile) {
    // Handle split input file mode
    auto splitOps = splitAndParseSourceBuffer(sourceMgr, &context, verifyDiagnostics);
    if (splitOps.empty()) {
      return failure();
    }
    
    // Process each split operation
    for (auto &splitOp : splitOps) {
      if (failed(processOperation(*splitOp, output->os()))) {
        return failure();
      }
    }
  } else {
    // Parse single operation
    op = parseSourceFile<ModuleOp>(sourceMgr, &context);
    if (!op) {
      return failure();
    }
    
    if (failed(processOperation(*op, output->os()))) {
      return failure();
    }
  }

  output->keep();
  return success();
}

/// Process a single operation through the pass pipeline
LogicalResult processOperation(Operation &op, raw_ostream &os) {
  // Set up pass manager
  PassManager pm(&op.getContext());
  
  if (verifyPasses) {
    pm.enableVerifier(true);
  }
  
  // Build the pass pipeline
  buildPassPipeline(pm);
  
  // Run the passes
  if (failed(pm.run(&op))) {
    return failure();
  }
  
  // Print the result
  op.print(os);
  return success();
}

} // end anonymous namespace

int main(int argc, char **argv) {
  InitLLVM y(argc, argv);

  // Register all MLIR passes
  registerAllPasses();
  
  // Register Torch-MLIR passes
  torch::registerConversionPasses();

  // Parse command line options
  cl::ParseCommandLineOptions(argc, argv, "ONNX C Importer\n");

  // Set up MLIR context
  MLIRContext context;
  DialectRegistry registry;
  registerAllRequiredDialects(registry);
  context.appendDialectRegistry(registry);
  
  if (allowUnregisteredDialects) {
    context.allowUnregisteredDialects();
  }

  // Show dialects if requested
  if (showDialects) {
    outs() << "Registered Dialects:\n";
    for (const auto &dialect : context.getLoadedDialects()) {
      outs() << dialect->getNamespace() << "\n";
    }
    return 0;
  }

  // Process the input file
  if (failed(processFile(context, inputFilename, outputFilename))) {
    return 1;
  }

  return 0;
}
