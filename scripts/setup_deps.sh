#!/bin/bash
# Setup development dependencies for Enimate
# This script installs depot_tools and prepares for Skia compilation
# Designed for WSL2 on Windows with proxy support
# Dependencies are installed in the project directory

set -e

# Detect if running in WSL2
if grep -qi microsoft /proc/version 2>/dev/null; then
    IS_WSL2=true
    echo "Detected WSL2 environment"
else
    IS_WSL2=false
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
DEPS_DIR="$PROJECT_ROOT/_deps"

echo "Project root: $PROJECT_ROOT"
echo "Dependencies dir: $DEPS_DIR"
echo ""

# Setup proxy if available (configured for Windows proxy in WSL2)
if [ -n "$ALL_PROXY" ]; then
    export ALL_PROXY
    export all_proxy="$ALL_PROXY"
    echo "Using proxy from env: $ALL_PROXY"
elif [ "$IS_WSL2" = true ]; then
    # In WSL2, Windows localhost is reachable via $(cat /etc/resolv.conf | grep nameserver | awk '{print $2}')
    # Configure default proxy for Windows proxy on localhost:30000
    WINDOWS_HOST=$(cat /etc/resolv.conf | grep nameserver | awk '{print $2}')
    DEFAULT_PROXY="socks5://${WINDOWS_HOST}:30000"

    # Ask user if they want to use the default proxy
    echo "Detected WSL2. Default proxy configured: $DEFAULT_PROXY"
    read -p "Use this proxy? (Y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]] || [[ -z $REPLY ]]; then
        export ALL_PROXY="$DEFAULT_PROXY"
        export all_proxy="$DEFAULT_PROXY"
        echo "Using proxy: $ALL_PROXY"

        # Configure git to use proxy
        git config --global http.proxy "$DEFAULT_PROXY"
        git config --global https.proxy "$DEFAULT_PROXY"
        echo "Git proxy configured"
    else
        echo "Skipping proxy configuration"
    fi
fi

echo "=== Enimate Dependency Setup ==="
echo "Project root: $PROJECT_ROOT"
echo ""

# Check prerequisites
echo "[1/4] Checking prerequisites..."
if command -v python3 >/dev/null 2>&1; then
    PYTHON_CMD=python3
elif command -v python >/dev/null 2>&1; then
    PYTHON_CMD=python
else
    echo "Error: python3 required"
    if [ "$IS_WSL2" = true ]; then
        echo "Install with: sudo apt update && sudo apt install python3 python3-pip"
    fi
    exit 1
fi

command -v git >/dev/null 2>&1 || { 
    echo "Error: git required"
    if [ "$IS_WSL2" = true ]; then
        echo "Install with: sudo apt update && sudo apt install git"
    fi
    exit 1
}

command -v ninja >/dev/null 2>&1 || { 
    echo "Error: ninja required"
    if [ "$IS_WSL2" = true ]; then
        echo "Install with: sudo apt update && sudo apt install ninja-build"
    fi
    exit 1
}
echo "✓ All prerequisites satisfied (using $PYTHON_CMD)"

# Install depot_tools
echo ""
echo "[2/4] Setting up depot_tools..."
DEPOT_TOOLS="$DEPS_DIR/depot_tools"
if [ ! -d "$DEPS_DIR" ]; then
    mkdir -p "$DEPS_DIR"
fi

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
SKIA_DIR="$DEPS_DIR/skia"
if [ -d "$SKIA_DIR" ]; then
    echo "✓ Skia already exists at $SKIA_DIR"
    cd "$SKIA_DIR"
    git pull || echo "Warning: Could not update Skia"
else
    echo "Cloning Skia (this may take a while)..."
    git clone https://skia.googlesource.com/skia.git "$SKIA_DIR"
    cd "$SKIA_DIR"
    echo "Syncing dependencies..."
    $PYTHON_CMD tools/git-sync-deps
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
echo "1. Add depot_tools to your PATH (add to ~/.bashrc or ~/.zshrc):"
echo "   export PATH=\"\$PROJECT_ROOT/_deps/depot_tools:\$PATH\""
echo "2. Run the appropriate build script for your target platform:"
echo "   - build_skia_linux.sh (for Linux, requires WSL2 or native Linux)"
echo ""
echo "Dependencies installed in: $DEPS_DIR"
echo ""
if [ "$IS_WSL2" = true ] && [ -n "$ALL_PROXY" ]; then
    echo "Note: Proxy has been configured for this session."
    echo "To make it permanent, add to your ~/.bashrc:"
    echo "  export ALL_PROXY=\"$ALL_PROXY\""
    echo ""
fi
