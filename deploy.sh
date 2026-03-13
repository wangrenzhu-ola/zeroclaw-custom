#!/bin/bash
set -e

REMOTE_HOST="${1:-154.9.254.212}"
REMOTE_USER="${2:-root}"
REMOTE_PASS="${3:-i3mNVmjqfaSNYXa9}"
REPO_DIR="~/zeroclaw-custom"

echo "==> Updating remote server $REMOTE_HOST..."

# Ensure sshpass is available locally
if ! command -v sshpass &> /dev/null; then
    echo "Error: sshpass is required."
    exit 1
fi

sshpass -p "$REMOTE_PASS" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "$REMOTE_USER@$REMOTE_HOST" "
    set -e
    
    echo '==> Checking dependencies...'
    # Check if git is installed
    if ! command -v git &> /dev/null; then
        echo 'Installing git...'
        if command -v apt-get &> /dev/null; then
            apt-get update && apt-get install -y git build-essential curl
        elif command -v yum &> /dev/null; then
            yum install -y git curl
        elif command -v apk &> /dev/null; then
            apk add git curl build-base
        fi
    fi

    if [ -d \"$REPO_DIR\" ]; then
        echo '==> Updating existing repo...'
        cd \"$REPO_DIR\"
        git pull
    else
        echo '==> Cloning repo...'
        # Try HTTPS first as it doesn't require SSH keys setup
        git clone https://github.com/wangrenzhu-ola/zeroclaw-custom.git \"$REPO_DIR\"
    fi

    cd \"$REPO_DIR\"
    
    echo '==> Running install.sh...'
    # Run install.sh with system deps and rust installation
    # Force source build since we are on dev branch
    ./install.sh --no-guided --install-system-deps --install-rust --force-source-build --skip-install
    
    # We skip install to cargo bin to just verify build, or remove --skip-install to install it.
    # User said \"deploy\", so usually install.
    # Let's run full install.
    ./install.sh --no-guided --install-system-deps --install-rust --force-source-build
    
    echo '==> Remote setup complete.'
"

echo "==> Deployment complete."
