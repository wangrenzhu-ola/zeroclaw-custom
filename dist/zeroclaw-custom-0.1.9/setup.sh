#!/bin/bash
set -e
APP_DIR="$HOME/.zeroclaw"
BIN_DIR="$HOME/.cargo/bin"

echo "==> Setting up ZeroClaw Environment..."

# 1. Install Dependencies
echo "  - Checking system dependencies..."
if ! command -v python3 &> /dev/null; then
    echo "    Installing python3..."
    if command -v apt-get &> /dev/null; then
        sudo apt-get update && sudo apt-get install -y python3 python3-pip python3-venv
    elif command -v apk &> /dev/null; then
        sudo apk add python3 py3-pip
    fi
fi

# 2. Install Binary
echo "  - Installing binary..."
mkdir -p "$BIN_DIR"

# Ensure we are in the right directory
if [ -f "zeroclaw" ]; then
    # Some archives might extract flat or differently
    cp zeroclaw "$BIN_DIR/"
elif [ -f "bin/zeroclaw" ]; then
    cp bin/zeroclaw "$BIN_DIR/"
elif [ -d "source" ]; then
    echo "    Compiling from source on remote..."
    
    # Install Rust if missing
    if ! command -v cargo &> /dev/null; then
        echo "    Installing Rust..."
        curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
        source "$HOME/.cargo/env"
    fi
    
    # Install build deps
    if command -v apt-get &> /dev/null; then
        sudo apt-get install -y build-essential pkg-config libssl-dev
    elif command -v apk &> /dev/null; then
        sudo apk add build-base pkgconf openssl-dev
    fi
    
    cd source
    cargo build --release --locked
    cp target/release/zeroclaw "$BIN_DIR/"
    cd ..
else
    echo "Error: No binary or source found in package."
    ls -F
    exit 1
fi

chmod +x "$BIN_DIR/zeroclaw"
# Ensure BIN_DIR is in PATH
if [[ ":$PATH:" != *":$BIN_DIR:"* ]]; then
    echo "export PATH=\"$BIN_DIR:$PATH\"" >> ~/.bashrc
    echo "export PATH=\"$BIN_DIR:$PATH\"" >> ~/.zshrc
fi

# 3. Setup Config
echo "  - Setting up config..."
mkdir -p "$APP_DIR"
if [ ! -f "$APP_DIR/config.toml" ]; then
    cp config/config.toml "$APP_DIR/"
    echo "    Config initialized at $APP_DIR/config.toml"
else
    echo "    Config already exists, skipping overwrite."
fi

# 4. Sync Skills
echo "  - Syncing skills..."
mkdir -p "$APP_DIR/skills"
cp -r skills/* "$APP_DIR/skills/"
echo "    Skills synced to $APP_DIR/skills/"

# 5. Setup Python Environment
echo "  - Setting up Python environment..."
if [ -d "python" ]; then
    mkdir -p "$APP_DIR/python"
    # Copy python files (overwrite)
    cp -r python/* "$APP_DIR/python/"
    
    cd "$APP_DIR/python"
    
    # Recreate venv to ensure consistency and fix broken states
    if [ -d "venv" ]; then
        echo "    Removing existing venv..."
        rm -rf venv
    fi
    
    echo "    Creating new venv..."
    python3 -m venv venv
    
    if [ -f "venv/bin/activate" ]; then
        source venv/bin/activate
        # Upgrade pip
        pip install --upgrade pip
        
        if [ -f "requirements.txt" ]; then
            echo "    Installing requirements..."
            pip install -r requirements.txt
        fi
        # Install package in editable mode if pyproject.toml exists
        if [ -f "pyproject.toml" ]; then
            pip install -e .
        fi
        deactivate
        echo "    Python environment ready at $APP_DIR/python/venv"
    else
        echo "Error: Failed to create venv. 'venv/bin/activate' not found."
        exit 1
    fi
fi

echo "==> Setup complete. Use $APP_DIR/zeroclaw_remote.sh to start/stop."
# Move zeroclaw_remote.sh to APP_DIR
if [ -f "zeroclaw_remote.sh" ]; then
    cp zeroclaw_remote.sh "$APP_DIR/"
    chmod +x "$APP_DIR/zeroclaw_remote.sh"
else
    echo "Warning: zeroclaw_remote.sh not found in package."
fi
