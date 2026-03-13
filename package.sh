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

# Scripts (if any useful ones exist, e.g. for install)
# Maybe copy this package script itself or a setup script?
# Let's create a simple setup.sh for the remote end
cat <<EOF > "${STAGING_DIR}/setup.sh"
#!/bin/bash
set -e
echo "==> Setting up ZeroClaw..."

# Check dependencies
command -v python3 >/dev/null 2>&1 || { echo "python3 not found"; exit 1; }

# Install binary
if [ -w "/usr/local/bin" ]; then
    cp bin/zeroclaw /usr/local/bin/
else
    mkdir -p ~/bin
    cp bin/zeroclaw ~/bin/
    echo "Added to ~/bin. Ensure it is in your PATH."
fi

# Setup config
if [ ! -f ~/.zeroclaw/config.toml ]; then
    mkdir -p ~/.zeroclaw
    cp config/config.toml ~/.zeroclaw/
    echo "Config copied to ~/.zeroclaw/config.toml"
fi

echo "==> Setup complete. Run 'zeroclaw' to start."
EOF
chmod +x "${STAGING_DIR}/setup.sh"

# 3. Create Archive
echo "==> Creating archive..."
tar -czf "${DIST_DIR}/${PACKAGE_NAME}.tar.gz" -C "${DIST_DIR}" "${PACKAGE_NAME}"

echo "==> Package created: ${DIST_DIR}/${PACKAGE_NAME}.tar.gz"
