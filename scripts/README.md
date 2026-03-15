# Enimate Build Scripts

This directory contains scripts for setting up dependencies and building Skia for multiple target platforms.

**Important**: All dependencies are installed in the `_deps/` directory within the project, which is ignored by git.

## Quick Start

### Prerequisites

1. **Git** - Install from https://git-scm.com/download/win
2. **Python 3** - Install from https://www.python.org/downloads/
3. **Visual Studio Build Tools** - Install from https://visualstudio.microsoft.com/downloads/
   - Select "Desktop development with C++" workload
4. **Emscripten** (for WASM builds only) - Install from https://emscripten.org/docs/getting_started/downloads.html

### Initial Setup

Run the setup script to install depot_tools and download Skia:

**On Windows:**
```cmd
scripts\setup_deps.bat
```

**On Linux/WSL2:**
```bash
./scripts/setup_deps.sh
```

This will:
- Install depot_tools in `_deps/depot_tools`
- Clone Skia to `_deps/skia`
- Set up project directories

**Note**: The `_deps/` directory is ignored by git, so dependencies won't be committed to the repository.

## Building for Different Platforms

### Build for Windows (x64)

```cmd
scripts\build_skia_windows.bat
```

This creates `native\lib\skia_windows.lib`

### Build for WebAssembly (wasm32)

First, activate Emscripten environment:
```cmd
emsdk\emsdk_env.bat
```

Then build:
```cmd
scripts\build_skia_wasm.bat
```

This creates `native\lib\skia_wasm.a`

### Build for Linux (x64)

First, run setup in WSL2:
```bash
wsl bash scripts/setup_deps.sh
```

Then build:
```cmd
wsl bash scripts/build_skia_linux.sh
```

This creates `native\lib\libskia.a`

### Build for All Platforms

```cmd
scripts\build_all.bat
```

This will build for Windows and WASM, and prompt you for Linux build.

## Environment Variables

### Proxy Configuration

If you need to use a proxy, set the `ALL_PROXY` environment variable:

```cmd
set ALL_PROXY=socks5://localhost:30000
```

The setup script will automatically use this proxy for git operations.

### PATH Configuration

After setup, add depot_tools to your PATH:

**Windows:**
```cmd
set PATH=%PROJECT_ROOT%\_deps\depot_tools;%PATH%
```

**Linux/WSL2:**
```bash
export PATH="$PROJECT_ROOT/_deps/depot_tools:$PATH"
```

For permanent configuration, add this line to your Environment Variables (Windows) or `~/.bashrc` (Linux).

## Project Structure

After setup, your project will have:

```
enimate/
├── _deps/                  # Dependencies (ignored by git)
│   ├── depot_tools/        # Build tools
│   └── skia/               # Skia source code
├── native/
│   ├── include/
│   │   └── skia/          # Symlink/junction to Skia headers (ignored by git)
│   └── lib/
│       ├── skia_windows.lib
│       ├── skia_wasm.a
│       └── libskia.a
```

**Important**: The `_deps/` directory and build artifacts in `native/` are ignored by git.

## Troubleshooting

### Visual Studio not found
Make sure you have Visual Studio Build Tools 2019 or 2022 installed with the "Desktop development with C++" workload.

### gn command not found
Make sure `_deps/depot_tools` is in your PATH.

### Emscripten errors
Make sure you've activated the Emscripten environment by running `emsdk\emsdk_env.bat` before building.

### WSL2 not available
You can install WSL2 on Windows 10/11:
```cmd
wsl --install
```

### Build takes too long
Skia builds can take 10-30 minutes depending on your hardware. This is normal.

## Advanced

### Custom Build Configuration

Each build script creates a `args.gn` file in the Skia build directory. You can modify these files to customize the build configuration.

See Skia's build documentation for more options: https://skia.org/user/build

### Cross-Compilation Notes

- **Windows**: Uses Visual Studio compiler (MSVC)
- **WASM**: Uses Emscripten (clang-based)
- **Linux**: Uses GCC (in WSL2 or native Linux)

All builds use CPU-only Skia backend (no GPU support) for simplicity and portability.
