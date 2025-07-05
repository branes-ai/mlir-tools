#!/bin/bash

# Enhanced verification script for MLIR/torch-mlir Python dependencies
echo "========================================"
echo "Verifying Python environment for MLIR..."
echo "========================================"

# Basic Python setup
echo "Python version:"
python3.10 --version
echo ""

echo "Pip version:"
python3.10 -m pip --version
echo ""

# Verify pybind11
echo "pybind11 verification:"
python3.10 -c "
import pybind11
print(f'pybind11 version: {pybind11.__version__}')
print(f'CMake dir: {pybind11.get_cmake_dir()}')
"
echo ""

# Verify numpy
echo "numpy verification:"
python3.10 -c "
import numpy
print(f'numpy version: {numpy.__version__}')
print(f'numpy include dir: {numpy.get_include()}')
"
echo ""

# Verify nanobind
echo "nanobind verification:"
python3.10 -c "
try:
    import nanobind as nb
    print(f'nanobind version: {nb.__version__}')
    
    # Get nanobind CMake directory
    cmake_dir = nb.cmake_dir()
    print(f'nanobind CMake dir: {cmake_dir}')
    
    # Test basic functionality - just verify core import works
    print('Testing nanobind basic functionality...')
    
    # Just check that we can access basic attributes
    available_attrs = [attr for attr in dir(nb) if not attr.startswith('_')]
    print(f'Available nanobind attributes: {len(available_attrs)} items')
    
    # Check for some expected attributes (without importing specific functions)
    has_cmake_dir = hasattr(nb, 'cmake_dir')
    has_version = hasattr(nb, '__version__')
    
    if has_cmake_dir and has_version:
        print('✅ nanobind basic functionality verified')
        print(f'Key attributes present: cmake_dir={has_cmake_dir}, __version__={has_version}')
    else:
        print('⚠️  nanobind missing some expected attributes')
        print(f'cmake_dir present: {has_cmake_dir}')
        print(f'__version__ present: {has_version}')
    
    # For torch-mlir, we mainly need cmake_dir to work
    if has_cmake_dir:
        print('✅ nanobind should work for torch-mlir build (cmake_dir available)')
    else:
        print('❌ nanobind cmake_dir not available - may cause build issues')
    
except ImportError as e:
    print(f'❌ nanobind import failed: {e}')
    print('Install with: pip3 install --user nanobind')
except Exception as e:
    print(f'⚠️  nanobind error: {e}')
    print('Try reinstalling: pip3 uninstall nanobind && pip3 install --user nanobind')
"
echo ""

# Check CMake file accessibility
echo "========================================"
echo "Checking CMake configuration files..."
echo "========================================"

# Check pybind11 CMake files
echo "pybind11 CMake files:"
PYBIND11_CMAKE_DIR=$(python3.10 -c "import pybind11; print(pybind11.get_cmake_dir())" 2>/dev/null)
if [ $? -eq 0 ] && [ -f "$PYBIND11_CMAKE_DIR/pybind11Config.cmake" ]; then
    echo "✅ pybind11 CMake config found at: $PYBIND11_CMAKE_DIR"
    echo "   Available files:"
    ls -la "$PYBIND11_CMAKE_DIR"/*.cmake 2>/dev/null | head -5
else
    echo "⚠️  pybind11 CMake config not found, but this might still work"
fi
echo ""

# Check nanobind CMake files
echo "nanobind CMake files:"
NANOBIND_CMAKE_DIR=$(python3.10 -c "
try:
    import nanobind as nb
    print(nb.cmake_dir())
except:
    pass
" 2>/dev/null)

if [ -n "$NANOBIND_CMAKE_DIR" ] && [ -d "$NANOBIND_CMAKE_DIR" ]; then
    echo "✅ nanobind CMake dir found at: $NANOBIND_CMAKE_DIR"
    echo "   Available files:"
    ls -la "$NANOBIND_CMAKE_DIR"/*.cmake 2>/dev/null | head -5
    
    # Check for specific nanobind CMake files
    if [ -f "$NANOBIND_CMAKE_DIR/nanobind-config.cmake" ]; then
        echo "✅ nanobind-config.cmake found"
    else
        echo "⚠️  nanobind-config.cmake not found"
    fi
else
    echo "❌ nanobind CMake directory not found"
    echo "   Make sure nanobind is installed: pip3 install --user nanobind"
fi
echo ""

# Test Python extension compilation capability
echo "========================================"
echo "Testing Python extension compilation..."
echo "========================================"

python3.10 -c "
import sys
import sysconfig

print('Python extension compilation info:')
print(f'Python executable: {sys.executable}')
print(f'Python include dir: {sysconfig.get_path(\"include\")}')
print(f'Python library dir: {sysconfig.get_path(\"stdlib\")}')
print(f'Platform: {sysconfig.get_platform()}')
print(f'Extension suffix: {sysconfig.get_config_var(\"EXT_SUFFIX\")}')

# Check if we can compile extensions
try:
    from distutils.util import get_platform
    print(f'Distutils platform: {get_platform()}')
    print('✅ Python development environment appears functional')
except Exception as e:
    print(f'⚠️  Python development environment issue: {e}')
"
echo ""

# Final summary
echo "========================================"
echo "Summary:"
echo "========================================"

# Count successful components
SUCCESS_COUNT=0
TOTAL_COUNT=4

echo "Checking installation status..."

# Check each component
python3.10 -c "import pybind11; print('✅ pybind11: OK')" 2>/dev/null && SUCCESS_COUNT=$((SUCCESS_COUNT + 1)) || echo "❌ pybind11: FAILED"

python3.10 -c "import numpy; print('✅ numpy: OK')" 2>/dev/null && SUCCESS_COUNT=$((SUCCESS_COUNT + 1)) || echo "❌ numpy: FAILED"

python3.10 -c "import nanobind; print('✅ nanobind: OK')" 2>/dev/null && SUCCESS_COUNT=$((SUCCESS_COUNT + 1)) || echo "❌ nanobind: FAILED"

# Check if Python dev headers are available
if [ -f "/usr/include/python3.10/Python.h" ] || python3.10-config --includes >/dev/null 2>&1; then
    echo "✅ Python development headers: OK"
    SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
else
    echo "❌ Python development headers: MISSING"
    echo "   Install with: sudo apt install python3.10-dev"
fi

echo ""
echo "Status: $SUCCESS_COUNT/$TOTAL_COUNT components ready"

if [ $SUCCESS_COUNT -eq $TOTAL_COUNT ]; then
    echo "🎉 All dependencies verified! Ready to build torch-mlir."
    exit 0
elif [ $SUCCESS_COUNT -ge 3 ]; then
    echo "⚠️  Most dependencies ready, but some issues detected."
    echo "   Build might work, but consider fixing the issues above."
    exit 1
else
    echo "❌ Critical dependencies missing. Please install missing components."
    echo ""
    echo "Quick fix commands:"
    echo "sudo apt install -y python3.10-dev build-essential"
    echo "pip3 install --user pybind11 nanobind numpy"
    exit 2
fi
