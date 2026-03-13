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
