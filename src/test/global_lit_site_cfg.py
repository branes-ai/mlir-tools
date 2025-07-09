# -*- Python -*-

# Configuration file for the 'lit' test runner.

import sys

config.mlir_tools_obj_root = r"@CMAKE_CURRENT_BINARY_DIR@"
config.mlir_tools_src_root = r"@CMAKE_CURRENT_SOURCE_DIR@"
config.mlir_tools_tools_dir = r"@CMAKE_CURRENT_BINARY_DIR@"
config.llvm_tools_dir = r"@TORCHMLIR_INSTALL_DIR@/bin"
config.llvm_shlib_ext = r"@LLVM_SHLIBEXT@"
config.llvm_exe_ext = r"@CMAKE_EXECUTABLE_SUFFIX@"
config.lit_tools_dir = r"@TORCHMLIR_INSTALL_DIR@/bin"
config.python_executable = r"@Python3_EXECUTABLE@"
config.onnx_c_importer_obj_root = r"@CMAKE_CURRENT_BINARY_DIR@/onnx_c_importer"
config.onnx_c_importer_tools_dir = r"@CMAKE_CURRENT_BINARY_DIR@"

# Support substitution of the tools_dir with user parameters. This is
# used when we can't determine the tool dir at configuration time.
try:
    config.llvm_tools_dir = config.llvm_tools_dir % lit_config.params
    config.mlir_tools_tools_dir = config.mlir_tools_tools_dir % lit_config.params
except KeyError:
    e = sys.exc_info()[1]
    key, = e.args
    lit_config.fatal("unable to find %r parameter, use '--param=%s=VALUE'" % (key,key))

import lit.llvm
lit.llvm.initialize(lit_config, config)

# Let the main config do the real work.
lit_config.load_config(
    config, os.path.join(config.mlir_tools_src_root, "test", "lit.cfg.py"))
