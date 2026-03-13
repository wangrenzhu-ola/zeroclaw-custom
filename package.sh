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
# Ensure we are using the correct rust toolchain
source "$HOME/.cargo/env" || true
cargo build --release --locked

# 2. Copy artifacts
echo "==> Collecting artifacts..."

# Binary
mkdir -p "${STAGING_DIR}/bin"
cp target/release/zeroclaw "${STAGING_DIR}/bin/"

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

# Create setup script
cat <<EOF > "${STAGING_DIR}/setup.sh"
#!/bin/bash
set -e
APP_DIR="\$HOME/.zeroclaw"
BIN_DIR="\$HOME/.cargo/bin"

echo "==> Setting up ZeroClaw Environment..."

# 1. Install Dependencies
echo "  - Checking system dependencies..."
if command -v apt-get &> /dev/null; then
    echo "    Detected apt-get. Installing dependencies..."
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -qq
    apt-get install -y python3 python3-pip python3-venv python3-full git curl
elif command -v apk &> /dev/null; then
    echo "    Detected apk. Installing dependencies..."
    apk add python3 py3-pip git curl
fi

# Ensure python3 is available
if ! command -v python3 &> /dev/null; then
    echo "Error: python3 could not be installed."
    exit 1
fi

# 2. Install Binary
echo "  - Installing binary..."
mkdir -p "\$BIN_DIR"
cp bin/zeroclaw "\$BIN_DIR/"
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

echo "==> Setup complete. Restart shell or source ~/.bashrc to update PATH."
echo "==> Run 'zeroclaw agent' to start."
EOF
chmod +x "${STAGING_DIR}/setup.sh"

# 3. Create Archive
echo "==> Creating archive..."
tar -czf "${DIST_DIR}/${PACKAGE_NAME}.tar.gz" -C "${DIST_DIR}" "${PACKAGE_NAME}"

echo "==> Package created: ${DIST_DIR}/${PACKAGE_NAME}.tar.gz"
