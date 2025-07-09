#!/usr/bin/env python3
"""
Smart build helper for mlir-tools project.
Provides fast, incremental builds and avoids unnecessary rebuilds.
"""

import argparse
import os
import subprocess
import sys
import time
from pathlib import Path
import shutil

class Colors:
    """ANSI color codes for colored output."""
    HEADER = '\033[95m'
    OKBLUE = '\033[94m'
    OKCYAN = '\033[96m'
    OKGREEN = '\033[92m'
    WARNING = '\033[93m'
    FAIL = '\033[91m'
    ENDC = '\033[0m'
    BOLD = '\033[1m'
    UNDERLINE = '\033[4m'

def print_colored(message, color=Colors.OKGREEN):
    """Print a colored message."""
    print(f"{color}{message}{Colors.ENDC}")

def print_header(message):
    """Print a header message."""
    print_colored(f"\n=== {message} ===", Colors.HEADER)

def print_error(message):
    """Print an error message."""
    print_colored(f"ERROR: {message}", Colors.FAIL)

def print_warning(message):
    """Print a warning message."""
    print_colored(f"WARNING: {message}", Colors.WARNING)

def run_command(cmd, cwd=None, capture_output=False):
    """Run a command and return the result."""
    print_colored(f"Running: {' '.join(cmd) if isinstance(cmd, list) else cmd}", Colors.OKCYAN)
    
    try:
        if capture_output:
            result = subprocess.run(cmd, cwd=cwd, capture_output=True, text=True, shell=True)
            return result.returncode == 0, result.stdout, result.stderr
        else:
            result = subprocess.run(cmd, cwd=cwd, shell=True)
            return result.returncode == 0, "", ""
    except Exception as e:
        print_error(f"Command failed: {e}")
        return False, "", str(e)

def check_torch_mlir_status(build_dir):
    """Check if torch-mlir is already built and up to date."""
    torch_mlir_install = build_dir / "ext" / "torch-mlir-install"
    
    if not torch_mlir_install.exists():
        return False, "Install directory doesn't exist"
    
    key_files = [
        torch_mlir_install / "bin" / "torch-mlir-opt",
        torch_mlir_install / "lib" / "cmake" / "torch-mlir" / "TorchMLIRConfig.cmake",
        torch_mlir_install / "include" / "torch-mlir" / "Dialect" / "Torch" / "IR" / "TorchDialect.h"
    ]
    
    for file_path in key_files:
        if not file_path.exists():
            return False, f"Missing key file: {file_path}"
    
    return True, "Torch-MLIR appears to be built"

def get_build_dir(source_dir):
    """Get or create the build directory."""
    build_dir = source_dir / "build"
    build_dir.mkdir(exist_ok=True)
    return build_dir

def configure_project(source_dir, build_dir, args):
    """Configure the CMake project."""
    print_header("Configuring Project")
    
    cmake_args = [
        "cmake",
        "-S", str(source_dir),
        "-B", str(build_dir),
        f"-DCMAKE_GENERATOR_IDENTIFIER={args.generator}",
        f"-DSKIP_TORCHMLIR_BUILD={'ON' if args.skip_torch_mlir else 'OFF'}",
        f"-DUSE_CCACHE={'ON' if args.use_ccache else 'OFF'}",
    ]
    
    if args.python_executable:
        cmake_args.append(f"-DPYTHON_EXECUTABLE={args.python_executable}")
    
    if args.prebuilt_torch_mlir:
        cmake_args.append(f"-DPREBUILT_TORCHMLIR_DIR={args.prebuilt_torch_mlir}")
    
    if args.tools:
        cmake_args.append(f"-DTOOLS_TO_BUILD={','.join(args.tools)}")
    
    success, _, _ = run_command(cmake_args, cwd=source_dir)
    return success

def build_target(build_dir, target, parallel_jobs=None):
    """Build a specific target."""
    print_header(f"Building {target}")
    
    cmd = ["cmake", "--build", str(build_dir), "--target", target]
    
    if parallel_jobs:
        cmd.extend(["--parallel", str(parallel_jobs)])
    
    success, _, _ = run_command(cmd, cwd=build_dir)
    return success

def main():
    parser = argparse.ArgumentParser(description="Smart build helper for mlir-tools")
    
    # Build targets
    parser.add_argument("action", nargs="?", default="tools",
                       choices=["configure", "torch-mlir", "tools", "all", "clean", "status"],
                       help="Action to perform")
    
    # Configuration options
    parser.add_argument("--generator", default="NINJA", choices=["NINJA", "MSVC"],
                       help="CMake generator to use")
    parser.add_argument("--python-executable", 
                       help="Python executable to use")
    parser.add_argument("--prebuilt-torch-mlir",
                       help="Path to pre-built torch-mlir installation")
    parser.add_argument("--skip-torch-mlir", action="store_true",
                       help="Skip torch-mlir build if already present")
    parser.add_argument("--use-ccache", action="store_true", default=True,
                       help="Use ccache for faster compilation")
    
    # Build options
    parser.add_argument("--tools", nargs="+",
                       help="Specific tools to build (default: all)")
    parser.add_argument("-j", "--parallel-jobs", type=int, default=2,
                       help="Number of parallel jobs")
    parser.add_argument("--force", action="store_true",
                       help="Force rebuild even if not needed")
    
    # Paths
    parser.add_argument("--source-dir", type=Path, default=Path.cwd(),
                       help="Source directory (default: current directory)")
    parser.add_argument("--build-dir", type=Path,
                       help="Build directory (default: source_dir/build)")
    
    args = parser.parse_args()
    
    # Resolve paths
    source_dir = args.source_dir.resolve()
    build_dir = args.build_dir.resolve() if args.build_dir else get_build_dir(source_dir)
    
    print_header("MLIR Tools Smart Build Helper")
    print(f"Source directory: {source_dir}")
    print(f"Build directory: {build_dir}")
    print(f"Action: {args.action}")
    
    # Check if we're in the right directory
    if not (source_dir / "CMakeLists.txt").exists():
        print_error("No CMakeLists.txt found in source directory")
        return 1
    
    if args.action == "status":
        print_header("Build Status")
        torch_mlir_ok, torch_mlir_msg = check_torch_mlir_status(build_dir)
        print(f"Torch-MLIR status: {torch_mlir_msg}")
        
        if (build_dir / "src").exists():
            print("Tools build directory exists")
        else:
            print("Tools not yet built")
        
        return 0
    
    elif args.action == "clean":
        print_header("Cleaning Build Directory")
        if build_dir.exists():
            shutil.rmtree(build_dir)
            print_colored("Build directory cleaned", Colors.OKGREEN)
        else:
            print_colored("Build directory doesn't exist", Colors.WARNING)
        return 0
    
    elif args.action == "configure":
        success = configure_project(source_dir, build_dir, args)
        return 0 if success else 1
    
    else:
        # Ensure project is configured
        if not (build_dir / "CMakeCache.txt").exists():
            print_header("Project not configured, configuring now...")
            if not configure_project(source_dir, build_dir, args):
                return 1
        
        # Check torch-mlir status for smart building
        if not args.force:
            torch_mlir_ok, torch_mlir_msg = check_torch_mlir_status(build_dir)
            if torch_mlir_ok and not args.skip_torch_mlir:
                print_colored(f"Torch-MLIR already built: {torch_mlir_msg}", Colors.OKGREEN)
                args.skip_torch_mlir = True
        
        # Build based on action
        start_time = time.time()
        
        if args.action == "torch-mlir":
            success = build_target(build_dir, "torch-mlir", args.parallel_jobs)
        elif args.action == "tools":
            if args.tools:
                # Build specific tools
                success = True
                for tool in args.tools:
                    if not build_target(build_dir, tool, args.parallel_jobs):
                        success = False
                        break
            else:
                success = build_target(build_dir, "tools", args.parallel_jobs)
        elif args.action == "all":
            success = build_target(build_dir, "all", args.parallel_jobs)
        
        end_time = time.time()
        build_time = end_time - start_time
        
        if success:
            print_colored(f"\nBuild completed successfully in {build_time:.1f} seconds!", Colors.OKGREEN)
            
            # Show installed tools
            install_dir = build_dir / "install" / "bin"
            if install_dir.exists():
                tools = list(install_dir.glob("*"))
                if tools:
                    print_colored(f"\nInstalled tools in {install_dir}:", Colors.HEADER)
                    for tool in tools:
                        print(f"  - {tool.name}")
        else:
            print_error(f"Build failed after {build_time:.1f} seconds")
            return 1
    
    return 0

if __name__ == "__main__":
    sys.exit(main())
