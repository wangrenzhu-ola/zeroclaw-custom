#!/bin/bash
set -euo pipefail

# Configuration
APP_NAME="zeroclaw"
VERSION=$(grep '^version =' Cargo.toml | head -n1 | cut -d '"' -f2)
DIST_DIR="dist"
PACKAGE_NAME="${APP_NAME}-custom-${VERSION}"
STAGING_DIR="${DIST_DIR}/${PACKAGE_NAME}"

echo "==> Packaging ${APP_NAME} v${VERSION}..."

# Clean previous build
rm -rf "$DIST_DIR"
mkdir -p "$STAGING_DIR"

# 1. Build release binary
echo "==> Building release binary..."

BINARY_SOURCE=""
INCLUDE_SOURCE=false

if [[ "$(uname)" == "Darwin" ]]; then
    echo "    Detected macOS. Checking Docker for cross-compilation..."
    
    if command -v docker &> /dev/null && docker ps &> /dev/null; then
        echo "    Docker available. Building for Linux (x86_64)..."
        DOCKER_BUILDKIT=1 docker build --target builder -t zeroclaw-builder .
        container_id=$(docker create zeroclaw-builder)
        mkdir -p target/release
        docker cp "$container_id:/app/zeroclaw" target/release/zeroclaw-linux
        docker rm -v "$container_id"
        BINARY_SOURCE="target/release/zeroclaw-linux"
    else
        echo "⚠️  Docker not available/running. Cannot cross-compile."
        echo "    Will package source code for remote compilation."
        INCLUDE_SOURCE=true
    fi
else
    echo "    Building natively..."
    source "$HOME/.cargo/env" || true
    cargo build --release --locked
    BINARY_SOURCE="target/release/zeroclaw"
fi

# 2. Copy artifacts
echo "==> Collecting artifacts..."

# Binary or Source
mkdir -p "${STAGING_DIR}/bin"
if [[ -n "$BINARY_SOURCE" && -f "$BINARY_SOURCE" ]]; then
    cp "$BINARY_SOURCE" "${STAGING_DIR}/bin/zeroclaw"
fi

if [[ "$INCLUDE_SOURCE" == true ]]; then
    echo "    Including source code for remote build..."
    # Exclude target/, .git/, dist/ to save space
    mkdir -p "${STAGING_DIR}/source"
    rsync -av --exclude='target' --exclude='.git' --exclude='dist' . "${STAGING_DIR}/source/"
fi

# Config
mkdir -p "${STAGING_DIR}/config"
if [ -f "examples/config.example.toml" ]; then
    cp examples/config.example.toml "${STAGING_DIR}/config/config.toml"
elif [ -f "config.example.toml" ]; then
    cp config.example.toml "${STAGING_DIR}/config/config.toml"
else
    echo "Warning: config.example.toml not found"
    touch "${STAGING_DIR}/config/config.toml"
fi

# Python Tools
if [ -d "python" ]; then
    cp -r python "${STAGING_DIR}/"
fi

# Skills
echo "==> Collecting skills..."
mkdir -p "${STAGING_DIR}/skills"

# Copy repo skills
if [ -d ".claude/skills" ]; then
    cp -r .claude/skills/* "${STAGING_DIR}/skills/" 2>/dev/null || true
fi

# Copy local trading skill (from parent dir)
TRADING_SKILL_SRC="../.trae/skills/trading-agents-client"
if [ -d "$TRADING_SKILL_SRC" ]; then
    echo "  - Including trading-agents-client..."
    cp -r "$TRADING_SKILL_SRC" "${STAGING_DIR}/skills/"
else
    echo "Warning: trading-agents-client skill not found at $TRADING_SKILL_SRC"
fi

# Create setup script (simplified, just install)
cat <<EOF > "${STAGING_DIR}/setup.sh"
#!/bin/bash
set -e
APP_DIR="\$HOME/.zeroclaw"
BIN_DIR="\$HOME/.cargo/bin"

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
mkdir -p "\$BIN_DIR"

# Ensure we are in the right directory
if [ -f "zeroclaw" ]; then
    # Some archives might extract flat or differently
    cp zeroclaw "\$BIN_DIR/"
elif [ -f "bin/zeroclaw" ]; then
    cp bin/zeroclaw "\$BIN_DIR/"
elif [ -d "source" ]; then
    echo "    Compiling from source on remote..."
    
    # Install Rust if missing
    if ! command -v cargo &> /dev/null; then
        echo "    Installing Rust..."
        curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
        source "\$HOME/.cargo/env"
    fi
    
    # Install build deps
    if command -v apt-get &> /dev/null; then
        sudo apt-get install -y build-essential pkg-config libssl-dev
    elif command -v apk &> /dev/null; then
        sudo apk add build-base pkgconf openssl-dev
    fi
    
    cd source
    cargo build --release --locked
    cp target/release/zeroclaw "\$BIN_DIR/"
    cd ..
else
    echo "Error: No binary or source found in package."
    ls -F
    exit 1
fi

chmod +x "\$BIN_DIR/zeroclaw"
# Ensure BIN_DIR is in PATH
if [[ ":\$PATH:" != *":\$BIN_DIR:"* ]]; then
    echo "export PATH=\"\$BIN_DIR:\$PATH\"" >> ~/.bashrc
    echo "export PATH=\"\$BIN_DIR:\$PATH\"" >> ~/.zshrc
fi

# 3. Setup Config
echo "  - Setting up config..."
mkdir -p "\$APP_DIR"
if [ ! -f "\$APP_DIR/config.toml" ]; then
    cp config/config.toml "\$APP_DIR/"
    echo "    Config initialized at \$APP_DIR/config.toml"
else
    echo "    Config already exists, skipping overwrite."
fi

# 4. Sync Skills
echo "  - Syncing skills..."
mkdir -p "\$APP_DIR/skills"
cp -r skills/* "\$APP_DIR/skills/"
echo "    Skills synced to \$APP_DIR/skills/"

# 5. Setup Python Environment
echo "  - Setting up Python environment..."
if [ -d "python" ]; then
    mkdir -p "\$APP_DIR/python"
    # Copy python files (overwrite)
    cp -r python/* "\$APP_DIR/python/"
    
    cd "\$APP_DIR/python"
    
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
        echo "    Python environment ready at \$APP_DIR/python/venv"
    else
        echo "Error: Failed to create venv. 'venv/bin/activate' not found."
        exit 1
    fi
fi

echo "==> Setup complete. Use \$APP_DIR/zeroclaw_remote.sh to start/stop."
# Move zeroclaw_remote.sh to APP_DIR
if [ -f "zeroclaw_remote.sh" ]; then
    cp zeroclaw_remote.sh "\$APP_DIR/"
    chmod +x "\$APP_DIR/zeroclaw_remote.sh"
else
    echo "Warning: zeroclaw_remote.sh not found in package."
fi
EOF
chmod +x "${STAGING_DIR}/setup.sh"

# Create remote control script
cat <<EOF > "${STAGING_DIR}/zeroclaw_remote.sh"
#!/bin/bash
# Remote ZeroClaw Control Script

APP_DIR="\$HOME/.zeroclaw"
BIN_DIR="\$HOME/.cargo/bin"

# Function to start
start() {
    if pgrep -f "\$BIN_DIR/zeroclaw" > /dev/null; then
        echo "    ZeroClaw is already running."
        exit 1
    fi
    
    echo "    Starting ZeroClaw..."
    
    # Run in background
    if [ ! -z "\${MINIMAX_API_KEY}" ]; then
        echo "    Configuring MiniMax key..."
        export MINIMAX_API_KEY="\${MINIMAX_API_KEY}"
        export GROUP_ID="1886252427301937152"
    fi
    
    nohup "\$BIN_DIR/zeroclaw" gateway > "\$APP_DIR/zeroclaw.log" 2>&1 &
    echo "    ZeroClaw started. Log: \$APP_DIR/zeroclaw.log"
    echo "    Waiting for Pairing Code..."
    # Wait up to 10 seconds for the code to appear
    for i in {1..20}; do
        if grep -q "X-Pairing-Code:" "\$APP_DIR/zeroclaw.log"; then
            CODE=\$(grep "X-Pairing-Code:" "\$APP_DIR/zeroclaw.log" | tail -n1 | awk '{print \$NF}')
            echo ""
            echo "    ┌──────────────────────────────────────────────┐"
            echo "    │  🔑 Remote Pairing Code: \$CODE              │"
            echo "    └──────────────────────────────────────────────┘"
            echo ""
            return
        fi
        sleep 0.5
    done
    echo "    Timeout waiting for pairing code. Please check log."
}

# Function to stop
stop() {
    if pgrep -f "\$BIN_DIR/zeroclaw" > /dev/null; then
        pkill -f "\$BIN_DIR/zeroclaw"
        echo "    ZeroClaw stopped."
    else
        echo "    ZeroClaw is not running."
    fi
}

case "\$1" in
    start)
        start
        ;;
    stop)
        stop
        ;;
    restart)
        stop
        sleep 1
        start
        ;;
    *)
        echo "Usage: \$0 {start|stop|restart}"
        exit 1
        ;;
esac
EOF
chmod +x "${STAGING_DIR}/zeroclaw_remote.sh"

# 3. Create Archive
echo "==> Creating archive..."
tar -czf "${DIST_DIR}/${PACKAGE_NAME}.tar.gz" -C "${DIST_DIR}" "${PACKAGE_NAME}"

echo "==> Package created: ${DIST_DIR}/${PACKAGE_NAME}.tar.gz"
