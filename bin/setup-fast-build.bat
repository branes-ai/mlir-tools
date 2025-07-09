@echo off
echo ======================================================
echo MLIR Tools Fast Build Setup
echo ======================================================

set BUILD_DIR=D:\build\mlir-tools\build_msvc_fast

echo Creating build directory: %BUILD_DIR%
if not exist "%BUILD_DIR%" mkdir "%BUILD_DIR%"

echo.
echo Configuring with smart caching enabled...
cd /d "%BUILD_DIR%"

cmake ^
  -DCMAKE_GENERATOR_IDENTIFIER=MSVC ^
  -DSKIP_TORCHMLIR_BUILD=ON ^
  -DUSE_CCACHE=OFF ^
  -DLLVM_PARALLEL_COMPILE_JOBS=1 ^
  -DLLVM_PARALLEL_LINK_JOBS=1 ^
  -DPYTHON_EXECUTABLE=D:/Python/venv/p310/Scripts/python.exe ^
  -S F:/Users/tomtz/dev/branes/clones/mlir-tools ^
  -B "%BUILD_DIR%"

if errorlevel 1 (
    echo.
    echo ======================================================
    echo Configuration failed. Check the torch-mlir installation.
    echo ======================================================
    echo.
    echo To fix this, you have several options:
    echo.
    echo Option 1: Use existing build if available
    echo   Set PREBUILT_TORCHMLIR_DIR to point to existing installation
    echo.
    echo Option 2: Build torch-mlir separately first
    echo   cmake --build . --target torch-mlir
    echo.
    echo Option 3: Force rebuild everything
    echo   Use -DSKIP_TORCHMLIR_BUILD=OFF
    echo.
    pause
    exit /b 1
)

echo.
echo ======================================================
echo Configuration successful!
echo ======================================================
echo.
echo Next steps:
echo   1. Build tools only: cmake --build . --target tools
echo   2. Build everything: cmake --build .
echo   3. Check status: cmake --build . --target build-status
echo.
echo For fast development, use:
echo   cmake --build . --target rebuild-tools
echo.
pause