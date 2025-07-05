#!/bin/bash

# Complete setup script for torch-mlir dependencies on Ubuntu
set -e

echo "Setting up torch-mlir build dependencies..."

# Update system packages
sudo apt update

# Install basic build dependencies
sudo apt install -y \
    build-essential \
    cmake \
    ninja-build \
    git \
    wget \
    software-properties-common

# Install Python 3.10 with development headers
echo "Installing Python 3.10..."
sudo add-apt-repository ppa:deadsnakes/ppa -y
sudo apt update
sudo apt install -y \
    python3.10 \
    python3.10-dev \
    python3.10-venv \
    python3.10-distutils

# Install pip for Python 3.10
echo "Installing pip for Python 3.10..."
wget -q https://bootstrap.pypa.io/get-pip.py
python3.10 get-pip.py --user
rm get-pip.py

# Install pybind11, nanobind, and numpy (required by torch-mlir)
echo "Installing Python dependencies..."
python3.10 -m pip install --user --upgrade pip setuptools wheel
python3.10 -m pip install --user pybind11>=2.10 nanobind>=2.4 numpy

# Install pybind11 system package as well (for additional CMake support)
sudo apt install -y pybind11-dev python3-pybind11

# Verify installations
echo "Verifying installations..."
echo "Python version:"
python3.10 --version

echo "Pip version:"
python3.10 -m pip --version

echo "pybind11 version and CMake dir:"
python3.10 -c "import pybind11; print(f'pybind11 version: {pybind11.__version__}'); print(f'CMake dir: {pybind11.get_cmake_dir()}')"

echo "numpy version:"
python3.10 -c "import numpy; print(f'numpy version: {numpy.__version__}')"

# Check if pybind11 CMake files are accessible
PYBIND11_CMAKE_DIR=$(python3.10 -c "import pybind11; print(pybind11.get_cmake_dir())")
if [ -f "$PYBIND11_CMAKE_DIR/pybind11Config.cmake" ]; then
    echo "✅ pybind11 CMake config found at: $PYBIND11_CMAKE_DIR"
else
    echo "⚠️  pybind11 CMake config not found, but this might still work"
fi

# Verify nanobind
echo "nanobind verification:"
python3.10 -c "
try:
    import nanobind as nb
    print(f'nanobind version: {nb.__version__}')
	    
    # Get nanobind CMake directory
    cmake_dir = nb.cmake_dir()
    print(f'nanobind CMake dir: {cmake_dir}')

    # Test basic functionality
    print('Testing nanobind basic functionality...')

    # test that we can import the actual core components
    from nanobind import module_, class_, enum_
    print('✅ nanobind core components imported successfully')

except ImportError as e:
    print(f'❌ nanobind import failed: {e}')
    print('Install with: pip3 install --user nanobind')
except Exception as e:
    print(f'⚠️  nanobind imported but functionality test failed: {e}')
"
echo ""


echo ""
echo "🎉 Dependency setup complete!"
echo "You can now run your CMake build:"
echo "  cd build"
echo "  cmake .. -DCMAKE_GENERATOR_IDENTIFIER=NINJA"
echo "  make"
