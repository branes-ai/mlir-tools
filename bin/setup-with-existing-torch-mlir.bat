@echo off
echo ======================================================
echo MLIR Tools Setup with Existing Torch-MLIR
echo ======================================================

set SOURCE_DIR=F:/Users/tomtz/dev/branes/clones/mlir-tools
set BUILD_DIR=D:\build\mlir-tools\build_msvc_fast
set EXISTING_TORCH_MLIR=D:\build\mlir-tools\build_msvc\ext\torch-mlir-install

echo.
echo Checking for existing torch-mlir installation...
if exist "%EXISTING_TORCH_MLIR%\bin\torch-mlir-opt.exe" (
    echo Found existing torch-mlir at: %EXISTING_TORCH_MLIR%
    set USE_EXISTING=ON
    set PREBUILT_DIR=%EXISTING_TORCH_MLIR%
) else (
    echo No existing torch-mlir found at: %EXISTING_TORCH_MLIR%
    echo Will build from scratch...
    set USE_EXISTING=OFF
    set PREBUILT_DIR=
)

echo.
echo Creating build directory: %BUILD_DIR%
if not exist "%BUILD_DIR%" mkdir "%BUILD_DIR%"

echo.
echo Configuring project...
cd /d "%BUILD_DIR%"

if "%USE_EXISTING%"=="ON" (
    echo Using existing torch-mlir installation...
    cmake ^
      -DCMAKE_GENERATOR_IDENTIFIER=MSVC ^
      -DSKIP_TORCHMLIR_BUILD=ON ^
      -DPREBUILT_TORCHMLIR_DIR="%PREBUILT_DIR%" ^
      -DUSE_CCACHE=OFF ^
      -DPYTHON_EXECUTABLE=D:/Python/venv/p310/Scripts/python.exe ^
      -S "%SOURCE_DIR%" ^
      -B "%BUILD_DIR%"
) else (
    echo Building torch-mlir from scratch with conservative settings...
    cmake ^
      -DCMAKE_GENERATOR_IDENTIFIER=MSVC ^
      -DSKIP_TORCHMLIR_BUILD=OFF ^
      -DUSE_CCACHE=OFF ^
      -DLLVM_PARALLEL_COMPILE_JOBS=1 ^
      -DLLVM_PARALLEL_LINK_JOBS=1 ^
      -DPYTHON_EXECUTABLE=D:/Python/venv/p310/Scripts/python.exe ^
      -S "%SOURCE_DIR%" ^
      -B "%BUILD_DIR%"
)

if errorlevel 1 (
    echo.
    echo ======================================================
    echo Configuration failed!
    echo ======================================================
    pause
    exit /b 1
)

echo.
echo ======================================================
echo Configuration successful!
echo ======================================================
echo.
echo Current directory: %CD%
echo Build directory: %BUILD_DIR%
echo.

if "%USE_EXISTING%"=="ON" (
    echo Since we're using existing torch-mlir, you can build tools immediately:
    echo   cmake --build . --target tools
    echo.
    echo This should be very fast ^(minutes, not hours^)
    echo.
    echo Building tools now...
    cmake --build . --target tools
    
    if errorlevel 1 (
        echo.
        echo Tools build failed. Check the logs above.
        pause
        exit /b 1
    )
    
    echo.
    echo ======================================================
    echo SUCCESS! Tools built successfully!
    echo ======================================================
    echo.
    echo Your tools are installed in:
    echo   %BUILD_DIR%\install\bin\
    echo.
    echo To rebuild tools quickly in the future:
    echo   cd /d "%BUILD_DIR%"
    echo   cmake --build . --target rebuild-tools
    echo.
) else (
    echo Since we need to build torch-mlir from scratch:
    echo   1. First build torch-mlir: cmake --build . --target torch-mlir
    echo   2. Then build tools: cmake --build . --target tools
    echo.
    echo WARNING: The torch-mlir build will take 1-2 hours!
    echo.
)

echo For future builds, always work from: %BUILD_DIR%
echo.
pause
