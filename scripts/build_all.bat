@echo off
REM Build Skia for all target platforms
REM This script builds Skia for Windows, Linux, and WASM

setlocal enabledelayedexpansion

echo ========================================
echo   Enimate Multi-Platform Build Script
echo ========================================
echo.
echo This script will build Skia for:
echo   - Windows (x64)
echo   - WebAssembly (wasm32)
echo   - Linux (x64) - requires WSL2
echo.
pause

echo.
echo [1/3] Building for Windows...
call "%~dp0build_skia_windows.bat"
if errorlevel 1 (
    echo Error: Windows build failed
    exit /b 1
)

echo.
echo [2/3] Building for WebAssembly...
call "%~dp0build_skia_wasm.bat"
if errorlevel 1 (
    echo Error: WASM build failed
    echo Note: WASM build requires Emscripten
    echo Install from: https://emscripten.org/docs/getting_started/downloads.html
    exit /b 1
)

echo.
echo [3/3] Building for Linux...
echo Linux build requires WSL2 environment.
echo Would you like to build for Linux now? ^(Y/N^)
set /p BUILD_LINUX=

if /i "%BUILD_LINUX%"=="Y" (
    echo Attempting to build via WSL2...
    wsl bash "%~dp0build_skia_linux.sh"
    if errorlevel 1 (
        echo Warning: Linux build failed or WSL2 not available
        echo You can build Linux version manually by running:
        echo   wsl bash scripts/build_skia_linux.sh
    )
) else (
    echo Skipping Linux build. You can build later with:
    echo   wsl bash scripts/build_skia_linux.sh
)

echo.
echo ========================================
echo   Multi-Platform Build Complete!
echo ========================================
echo.
echo Built libraries available in native\lib\:
echo   - skia_windows.lib  (Windows)
echo   - skia_wasm.a       (WebAssembly)
if exist "%~dp0..\native\lib\libskia.a" (
    echo   - libskia.a        (Linux)
)
echo.
echo Next steps:
echo   Use MoonBit to compile for each target platform
echo.

endlocal
