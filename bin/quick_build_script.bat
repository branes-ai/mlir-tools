@echo off
setlocal

rem Set your build directory here
set BUILD_DIR=D:\build\mlir-tools\build_msvc_fast

rem Check if build directory exists
if not exist "%BUILD_DIR%" (
    echo Build directory does not exist: %BUILD_DIR%
    echo Please run setup-with-existing-torch-mlir.bat first
    pause
    exit /b 1
)

rem Parse command line arguments
set TARGET=tools
if not "%1"=="" set TARGET=%1

echo ======================================================
echo Quick Build Helper
echo ======================================================
echo Build directory: %BUILD_DIR%
echo Target: %TARGET%
echo.

rem Change to build directory
cd /d "%BUILD_DIR%"

rem Check what's available
if "%TARGET%"=="status" (
    echo Checking build status...
    cmake --build . --target build-status
    goto :end
)

if "%TARGET%"=="clean" (
    echo Cleaning tools build...
    cmake --build . --target rebuild-tools
    goto :end
)

if "%TARGET%"=="torch-mlir" (
    echo Building torch-mlir... ^(this will take a long time^)
    cmake --build . --target torch-mlir
    goto :end
)

rem Default: build tools
echo Building target: %TARGET%
cmake --build . --target %TARGET%

if errorlevel 1 (
    echo.
    echo ======================================================
    echo Build failed!
    echo ======================================================
    echo.
    echo Common solutions:
    echo   1. Make sure torch-mlir is built: quick-build.bat torch-mlir
    echo   2. Check status: quick-build.bat status
    echo   3. Clean rebuild: quick-build.bat clean
    echo.
    pause
    exit /b 1
)

echo.
echo ======================================================
echo Build successful!
echo ======================================================
echo.

if "%TARGET%"=="tools" (
    echo Your tools are in: %BUILD_DIR%\install\bin\
    echo.
    if exist "%BUILD_DIR%\install\bin\onnx-c-importer.exe" (
        echo Available tools:
        dir /b "%BUILD_DIR%\install\bin\*.exe"
    )
)

:end
echo.
echo For future builds, you can run:
echo   quick-build.bat [target]
echo.
echo Available targets:
echo   tools      - Build all tools ^(default^)
echo   torch-mlir - Build torch-mlir ^(slow^)
echo   status     - Check build status
echo   clean      - Clean rebuild tools
echo.
pause
