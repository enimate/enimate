@echo off
REM Build Skia for WebAssembly (wasm32)
REM Creates a library for WASM compilation

setlocal enabledelayedexpansion

set "SCRIPT_DIR=%~dp0"
set "PROJECT_ROOT=%SCRIPT_DIR%.."
set "DEPS_DIR=%PROJECT_ROOT%\_deps"
set "SKIA_DIR=%DEPS_DIR%\skia"
set "DEPOT_TOOLS=%DEPS_DIR%\depot_tools"

echo === Skia Build Script for WebAssembly (CPU Backend) ===
echo Skia source: %SKIA_DIR%
echo.

REM Check Skia exists
if not exist "%SKIA_DIR%" (
    echo Error: Skia not found at %SKIA_DIR%
    echo Please run scripts\setup_deps.bat first
    exit /b 1
)

REM Setup PATH
set "PATH=%DEPOT_TOOLS%;%PATH%"

REM Check gn is available
gn --version >nul 2>&1
if errorlevel 1 (
    echo Error: gn not found. Make sure depot_tools is in your PATH
    exit /b 1
)

REM Check Emscripten
if not defined EMSCRIPTEN (
    echo Error: EMSCRIPTEN environment variable not set
    echo Please install Emscripten and activate it:
    echo 1. Download from: https://emscripten.org/docs/getting_started/downloads.html
    echo 2. Run: emsdk\emsdk_env.bat
    exit /b 1
)

if not exist "%EMSCRIPTEN%" (
    echo Error: Emscripten not found at %EMSCRIPTEN%
    exit /b 1
)

cd /d "%SKIA_DIR%"

REM Create build configuration
set "BUILD_DIR=out\enimate_wasm_release"
echo [1/3] Configuring build (%BUILD_DIR%)...

if not exist "%BUILD_DIR%" mkdir "%BUILD_DIR%"

REM Write args.gn
(
echo # Target configuration
echo target_os = "wasm"
echo target_cpu = "wasm32"
echo.
echo # Build type
echo is_official_build = true
echo is_debug = false
echo is_component_build = false
echo.
echo # CPU-only backend (no GPU)
echo skia_enable_gpu = false
echo skia_use_vulkan = false
echo skia_use_gl = false
echo skia_use_metal = false
echo.
echo # Image format support
echo skia_use_system_libpng = false
echo skia_use_zlib = false
echo skia_use_libjpeg_turbo = true
echo skia_use_system_libjpeg_turbo = false
echo.
echo # Font support (minimal for MVP)
echo skia_enable_font_manager_empty = true
echo skia_use_system_freetype2 = false
echo.
echo # Disable unnecessary features
echo skia_enable_pdf = false
echo skia_enable_particles = false
echo skia_enable_skottie = false
echo skia_enable_svg = false
echo skia_enable_tools = false
echo skia_enable_android_utils = false
echo.
echo # WASM specific
echo cc = "emcc"
echo cxx = "em++"
echo ar = "emar"
echo nm = "emnm"
echo.
echo # Optimization
echo symbol_level = 1
) > "%BUILD_DIR%\args.gn"

echo Build configuration written

REM Generate build files
echo.
echo [2/3] Generating build files...
gn gen "%BUILD_DIR%"
if errorlevel 1 (
    echo Error: Failed to generate build files
    exit /b 1
)
echo Build files generated

REM Build Skia
echo.
echo [3/3] Building Skia for WASM (this may take 10-30 minutes)...
ninja -C "%BUILD_DIR%" skia
if errorlevel 1 (
    echo Error: Failed to build Skia
    exit /b 1
)
echo Skia built successfully

REM Copy to project
echo.
echo Copying Skia library to project...
if not exist "%PROJECT_ROOT%\native\lib" mkdir "%PROJECT_ROOT%\native\lib"
copy "%BUILD_DIR%\skia.a" "%PROJECT_ROOT%\native\lib\skia_wasm.a"
if errorlevel 1 (
    echo Error: Failed to copy library
    exit /b 1
)
echo skia_wasm.a copied to native\lib\

echo.
echo === Build Complete ===
echo.
echo Skia static library: %PROJECT_ROOT%\native\lib\skia_wasm.a
echo Source code location: %SKIA_DIR%
echo.

endlocal
