#!/bin/bash

# Safe nanobind diagnostic script
# This version includes error handling to prevent shell crashes

set +e  # Don't exit on errors
set +u  # Don't exit on undefined variables

echo "=== Safe Nanobind Diagnostic ==="
echo "Starting diagnostic (this should not crash your shell)..."

# Test 1: Basic Python execution
echo "Test 1: Basic Python test"
python3.10 -c "print('Python is working')" 2>&1
if [ $? -eq 0 ]; then
    echo "✅ Python3.10 execution works"
else
    echo "❌ Python3.10 execution failed"
    exit 1
fi

# Test 2: Can we import nanobind at all?
echo -e "\nTest 2: Nanobind import test"
NANOBIND_IMPORT_RESULT=$(python3.10 -c "
try:
    import nanobind
    print('SUCCESS: nanobind imported')
except Exception as e:
    print(f'FAILED: {e}')
" 2>&1)

echo "Import result: $NANOBIND_IMPORT_RESULT"

if [[ "$NANOBIND_IMPORT_RESULT" == *"SUCCESS"* ]]; then
    echo "✅ nanobind imports successfully"
    
    # Test 3: Get version safely
    echo -e "\nTest 3: Nanobind version check"
    VERSION_RESULT=$(python3.10 -c "
try:
    import nanobind as nb
    print(f'Version: {nb.__version__}')
except Exception as e:
    print(f'Version check failed: {e}')
" 2>&1)
    echo "$VERSION_RESULT"
    
    # Test 4: Check cmake_dir safely
    echo -e "\nTest 4: Nanobind cmake_dir test"
    CMAKE_RESULT=$(python3.10 -c "
try:
    import nanobind as nb
    cmake_dir = nb.cmake_dir()
    print(f'CMake dir: {cmake_dir}')
    import os
    if os.path.exists(cmake_dir):
        print('CMake directory exists')
    else:
        print('CMake directory does not exist')
except Exception as e:
    print(f'cmake_dir test failed: {e}')
" 2>&1)
    echo "$CMAKE_RESULT"
    
    # Test 5: List available attributes
    echo -e "\nTest 5: Available nanobind attributes"
    ATTRS_RESULT=$(python3.10 -c "
try:
    import nanobind as nb
    attrs = [attr for attr in dir(nb) if not attr.startswith('_')]
    print(f'Available attributes ({len(attrs)}): {attrs[:10]}...')
except Exception as e:
    print(f'Attributes check failed: {e}')
" 2>&1)
    echo "$ATTRS_RESULT"
    
else
    echo "❌ nanobind import failed"
    echo "Try: pip3 install --user nanobind"
fi

echo -e "\n=== Diagnostic Complete ==="
echo "If you're seeing this message, the script completed without crashing your shell."

