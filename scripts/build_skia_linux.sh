#!/bin/bash
# Build Skia for Linux (CPU-only backend)
# This creates a static library for Linux native compilation
# Can be run in WSL2 on Windows
# Dependencies are installed in the project directory

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
DEPS_DIR="$PROJECT_ROOT/_deps"
SKIA_DIR="$DEPS_DIR/skia"
DEPOT_TOOLS="$DEPS_DIR/depot_tools"

echo "=== Skia Build Script for Linux (CPU Backend) ==="
echo "Skia source: $SKIA_DIR"
echo ""

# Check Skia exists
if [ ! -d "$SKIA_DIR" ]; then
    echo "Error: Skia not found at $SKIA_DIR"
    echo "Please run ./scripts/setup_deps.sh first (in Linux/WSL2)"
    exit 1
fi

# Setup PATH
export PATH="$DEPOT_TOOLS:$PATH"

# Check gn is available
if ! command -v gn >/dev/null 2>&1; then
    echo "Error: gn not found. Make sure depot_tools is in your PATH"
    exit 1
fi

cd "$SKIA_DIR"

# Create build configuration
BUILD_DIR="out/enimate_linux_release"
echo "[1/3] Configuring build ($BUILD_DIR)..."

mkdir -p "$BUILD_DIR"

# Write args.gn
cat > "$BUILD_DIR/args.gn" << 'EOF'
# Target configuration
target_os = "linux"
target_cpu = "x64"

# Build type
is_official_build = true
is_debug = false
is_component_build = false

# CPU-only backend (no GPU)
skia_enable_gpu = false
skia_use_vulkan = false
skia_use_gl = false
skia_use_metal = false

# Image format support
skia_use_system_libpng = true
skia_use_system_zlib = true
skia_use_libjpeg_turbo = true
skia_use_system_libjpeg_turbo = true

# Font support (minimal for MVP)
skia_enable_font_manager_empty = true
skia_use_system_freetype2 = false

# Disable unnecessary features
skia_enable_pdf = false
skia_enable_particles = false
skia_enable_skottie = false
skia_enable_svg = false
skia_enable_tools = false
skia_enable_android_utils = false

# Optimization
symbol_level = 1

# Use C++17
ar = "ar"
cc = "gcc"
cxx = "g++"

# Disable AVX to avoid ABI issues with older GCC
skia_enable_avx = false
skia_enable_avx2 = false
skia_enable_avx512 = false
skia_enable_skx = false
skia_enable_ssse3 = false
skia_enable_sse41 = false
skia_enable_sse42 = false
EOF

echo "✓ Build configuration written"

# Generate build files
echo ""
echo "[2/3] Generating build files..."
gn gen "$BUILD_DIR"
echo "✓ Build files generated"

# Build Skia
echo ""
echo "[3/3] Building Skia (this may take 10-30 minutes)..."
ninja -C "$BUILD_DIR" skia
echo "✓ Skia built successfully"

# Copy to project
echo ""
echo "Copying Skia library to project..."
mkdir -p "$PROJECT_ROOT/native/lib"
cp "$BUILD_DIR/libskia.a" "$PROJECT_ROOT/native/lib/libskia.a"
echo "✓ libskia.a copied to native/lib/"

echo ""
echo "=== Build Complete ==="
echo ""
echo "Skia static library: $PROJECT_ROOT/native/lib/libskia.a"
echo "Source code location: $SKIA_DIR"
echo "This library can be used for Linux x64 targets"
echo ""
