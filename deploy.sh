#!/bin/bash
set -e

REMOTE_HOST="${1:-154.9.254.212}"
REMOTE_USER="${2:-root}"
REMOTE_PASS="${3:-i3mNVmjqfaSNYXa9}"
PACKAGE_FILE=$(ls dist/zeroclaw-custom-*.tar.gz 2>/dev/null | head -n1)

if [ -z "$PACKAGE_FILE" ]; then
    echo "Error: No package file found in dist/. Run ./package.sh first."
    exit 1
fi

echo "==> Deploying $PACKAGE_FILE to $REMOTE_USER@$REMOTE_HOST..."

# Ensure sshpass is available
if ! command -v sshpass &> /dev/null; then
    echo "Error: sshpass is required."
    exit 1
fi

# Upload
echo "==> Uploading package..."
sshpass -p "$REMOTE_PASS" scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "$PACKAGE_FILE" "$REMOTE_USER@$REMOTE_HOST:/tmp/"

# Install
echo "==> Running remote setup..."
sshpass -p "$REMOTE_PASS" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "$REMOTE_USER@$REMOTE_HOST" "
    cd /tmp
    # Clean previous extraction directory
    rm -rf \$(basename "$PACKAGE_FILE" .tar.gz)
    
    # Extract
    tar -xzf \$(basename "$PACKAGE_FILE")
    
    # Run setup
    cd \$(basename "$PACKAGE_FILE" .tar.gz)
    bash setup.sh
"

echo "==> Deployment complete."
