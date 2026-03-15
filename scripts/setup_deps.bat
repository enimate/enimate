@echo off
REM Setup development dependencies for Enimate (Windows version)
REM This script installs depot_tools and prepares for Skia compilation
REM Supports cross-compilation for Windows, Linux, and WASM
REM Dependencies are installed in the project directory

setlocal enabledelayedexpansion

set "SCRIPT_DIR=%~dp0"
set "PROJECT_ROOT=%SCRIPT_DIR%.."
set "DEPS_DIR=%PROJECT_ROOT%\_deps"

echo === Enimate Dependency Setup (Windows) ===
echo Project root: %PROJECT_ROOT%
echo Dependencies dir: %DEPS_DIR%
echo.

REM Check prerequisites
echo [1/4] Checking prerequisites...

REM Check Python
python --version >nul 2>&1
if errorlevel 1 (
    echo Error: Python required
    echo Install from: https://www.python.org/downloads/
    exit /b 1
)
set "PYTHON_CMD=python"

REM Check Git
git --version >nul 2>&1
if errorlevel 1 (
    echo Error: Git required
    echo Install from: https://git-scm.com/download/win
    exit /b 1
)

REM Check Visual Studio Build Tools
if not exist "C:\Program Files (x86)\Microsoft Visual Studio\2019\BuildTools\VC\Auxiliary\Build\vcvars64.bat" (
    if not exist "C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\VC\Auxiliary\Build\vcvars64.bat" (
        if not exist "C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Auxiliary\Build\vcvars64.bat" (
            echo Warning: Visual Studio Build Tools not found
            echo Install from: https://visualstudio.microsoft.com/downloads/
            echo Select "Desktop development with C++" workload
        )
    )
)

echo [2/4] Checking proxy settings...

REM Setup proxy if configured
if defined ALL_PROXY (
    echo Using proxy from env: %ALL_PROXY%
    set "HTTP_PROXY=%ALL_PROXY%"
    set "HTTPS_PROXY=%ALL_PROXY%"
) else (
    echo Note: Set ALL_PROXY environment variable if you need a proxy
    echo Example: set ALL_PROXY=socks5://localhost:30000
)

REM Install depot_tools
echo.
echo [3/4] Setting up depot_tools...
set "DEPOT_TOOLS=%DEPS_DIR%\depot_tools"

if not exist "%DEPS_DIR%" mkdir "%DEPS_DIR%"

if exist "%DEPOT_TOOLS%" (
    echo depot_tools already exists at %DEPOT_TOOLS%
    cd /d "%DEPOT_TOOLS%"
    git pull
    if errorlevel 1 (
        echo Warning: Could not update depot_tools
    ) else (
        echo Updated depot_tools
    )
) else (
    echo Cloning depot_tools...
    git clone https://chromium.googlesource.com/chromium/tools/depot_tools.git "%DEPOT_TOOLS%"
    if errorlevel 1 (
        echo Error: Failed to clone depot_tools
        exit /b 1
    )
    echo Cloned depot_tools to %DEPOT_TOOLS%
)

REM Add to PATH for current session
set "PATH=%DEPOT_TOOLS%;%PATH%"

REM Check if gn is available
gn --version >nul 2>&1
if errorlevel 1 (
    echo Warning: gn not in PATH. Make sure depot_tools is in your PATH
) else (
    echo gn is available
)

REM Clone Skia
echo.
echo [4/4] Setting up Skia...
set "SKIA_DIR=%DEPS_DIR%\skia"

if exist "%SKIA_DIR%" (
    echo Skia already exists at %SKIA_DIR%
    cd /d "%SKIA_DIR%"
    git pull
    if errorlevel 1 (
        echo Warning: Could not update Skia
    ) else (
        echo Updated Skia
    )
) else (
    echo Cloning Skia (this may take a while)...
    git clone https://skia.googlesource.com/skia.git "%SKIA_DIR%"
    if errorlevel 1 (
        echo Error: Failed to clone Skia
        exit /b 1
    )
    cd /d "%SKIA_DIR%"
    echo Syncing dependencies...
    %PYTHON_CMD% tools\git-sync-deps
    if errorlevel 1 (
        echo Error: Failed to sync Skia dependencies
        exit /b 1
    )
    echo Cloned and synced Skia
)

REM Create directories
echo.
echo Creating project directories...
if not exist "%PROJECT_ROOT%\native\include" mkdir "%PROJECT_ROOT%\native\include"
if not exist "%PROJECT_ROOT%\native\lib" mkdir "%PROJECT_ROOT%\native\lib"

REM Create junction to Skia include (Windows equivalent of symlink)
if not exist "%PROJECT_ROOT%\native\include\skia" (
    mklink /J "%PROJECT_ROOT%\native\include\skia" "%SKIA_DIR%"
    if errorlevel 1 (
        echo Warning: Failed to create junction, using directory instead
        xcopy "%SKIA_DIR%\include" "%PROJECT_ROOT%\native\include\skia\include\" /E /I /Y
    ) else (
        echo Created junction: native\include\skia -^> %SKIA_DIR%
    )
) else (
    echo Skia include junction already exists
)

echo.
echo === Setup Complete ===
echo.
echo Next steps:
echo 1. Add depot_tools to your PATH:
echo    set PATH=%%PROJECT_ROOT%%\_deps\depot_tools;%%PATH%%
echo 2. Run the appropriate build script for your target platform:
echo    - build_skia_windows.bat    (for Windows)
echo    - build_skia_wasm.bat       (for WebAssembly)
echo    - build_skia_linux.sh       (for Linux, requires WSL or Linux environment)
echo.
echo Note: For Linux builds on Windows, you can use WSL2 or Docker
echo Dependencies are installed in: %DEPS_DIR%
echo.

endlocal
