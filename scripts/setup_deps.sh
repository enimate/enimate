#!/bin/bash
# Setup development dependencies for Enimate
# This script installs depot_tools and prepares for Skia compilation

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Setup proxy if available (useful in certain network environments)
if [ -n "$ALL_PROXY" ]; then
    export ALL_PROXY
    export all_proxy="$ALL_PROXY"
    echo "Using proxy: $ALL_PROXY"
fi

echo "=== Enimate Dependency Setup ==="
echo "Project root: $PROJECT_ROOT"
echo ""

# Check prerequisites
echo "[1/4] Checking prerequisites..."
command -v python3 >/dev/null 2>&1 || { echo "Error: python3 required"; exit 1; }
command -v git >/dev/null 2>&1 || { echo "Error: git required"; exit 1; }
command -v ninja >/dev/null 2>&1 || { echo "Error: ninja required"; exit 1; }
echo "✓ All prerequisites satisfied"

# Install depot_tools
echo ""
echo "[2/4] Setting up depot_tools..."
DEPOT_TOOLS="$HOME/depot_tools"
if [ -d "$DEPOT_TOOLS" ]; then
    echo "✓ depot_tools already exists at $DEPOT_TOOLS"
    cd "$DEPOT_TOOLS"
    git pull || echo "Warning: Could not update depot_tools"
else
    echo "Cloning depot_tools..."
    git clone https://chromium.googlesource.com/chromium/tools/depot_tools.git "$DEPOT_TOOLS"
    echo "✓ depot_tools cloned to $DEPOT_TOOLS"
fi

# Add to PATH for current session
export PATH="$DEPOT_TOOLS:$PATH"

# Check if gn is available
if command -v gn >/dev/null 2>&1; then
    echo "✓ gn is available"
else
    echo "Warning: gn not in PATH. Add to your shell config:"
    echo "  export PATH=\"\$HOME/depot_tools:\$PATH\""
fi

# Clone Skia
echo ""
echo "[3/4] Setting up Skia..."
SKIA_DIR="$HOME/skia"
if [ -d "$SKIA_DIR" ]; then
    echo "✓ Skia already exists at $SKIA_DIR"
    cd "$SKIA_DIR"
    git pull || echo "Warning: Could not update Skia"
else
    echo "Cloning Skia (this may take a while)..."
    git clone https://skia.googlesource.com/skia.git "$SKIA_DIR"
    cd "$SKIA_DIR"
    echo "Syncing dependencies..."
    python3 tools/git-sync-deps
    echo "✓ Skia cloned and dependencies synced"
fi

# Create symlink to project
echo ""
echo "[4/4] Creating project symlinks..."
NATIVE_INCLUDE="$PROJECT_ROOT/native/include"
mkdir -p "$NATIVE_INCLUDE"
mkdir -p "$PROJECT_ROOT/native/lib"

# Create symlink to Skia include
if [ ! -L "$NATIVE_INCLUDE/skia" ]; then
    ln -sf "$SKIA_DIR" "$NATIVE_INCLUDE/skia"
    echo "✓ Created symlink: native/include/skia -> $SKIA_DIR"
else
    echo "✓ Skia include symlink already exists"
fi

echo ""
echo "=== Setup Complete ==="
echo ""
echo "Next steps:"
echo "1. Add depot_tools to your PATH (add to ~/.zshrc or ~/.bashrc):"
echo "   export PATH=\"\$HOME/depot_tools:\$PATH\""
echo "2. Run: ./scripts/build_skia.sh"
echo ""
