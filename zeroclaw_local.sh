#!/bin/bash
# Local Zeroclaw Startup Script

# Configuration
CONFIG_FILE="config.toml"
BINARY="./target/release/zeroclaw"

# Check if config exists, if not create from example
if [ ! -f "$CONFIG_FILE" ]; then
    if [ -f "examples/config.example.toml" ]; then
        cp examples/config.example.toml "$CONFIG_FILE"
        echo "Created $CONFIG_FILE from example."
    elif [ -f "dev/config.template.toml" ]; then
        cp dev/config.template.toml "$CONFIG_FILE"
        echo "Created $CONFIG_FILE from dev template."
    else
        # Minimal config
        cat <<EOF > "$CONFIG_FILE"
workspace_dir = "workspace"
default_provider = "minimax-cn"
default_model = "MiniMax-M2.5-highspeed"
default_temperature = 0.7

[gateway]
port = 42617
host = "127.0.0.1"
allow_public_bind = false
EOF
        echo "Created minimal $CONFIG_FILE."
    fi
fi

# Function to start
start() {
    if pgrep -f "$BINARY" > /dev/null; then
        echo "ZeroClaw is already running."
        exit 1
    fi
    
    echo "Starting ZeroClaw..."
    # Ensure binary exists
    if [ ! -f "$BINARY" ]; then
        echo "Binary not found. Building..."
        cargo build --release --locked
    fi
    
    # Set environment variables for MiniMax
    export MINIMAX_API_KEY="sk-cp-oPQB9N6tKZCICzNkHIywhKrHNiZmbJ_KZG2s-MDdB8Yyc9q5jIbBP4vaRVwV04_42JDeesO83C8mZDWOaJUiZc0eIcfuZkw7vbygAfxFoQR9dgBQD0DrjG0"
    export GROUP_ID="1886252427301937152"
    
    # Run in background
    nohup "$BINARY" gateway > zeroclaw.log 2>&1 &
    echo "ZeroClaw started. Log: zeroclaw.log"
    echo "Waiting for Pairing Code..."
    # Wait up to 10 seconds for the code to appear
    for i in {1..20}; do
        if grep -q "X-Pairing-Code:" zeroclaw.log; then
            CODE=$(grep "X-Pairing-Code:" zeroclaw.log | tail -n1 | awk '{print $NF}')
            echo ""
            echo "┌──────────────────────────────────────────────┐"
            echo "│  🔑 Local Pairing Code: $CODE               │"
            echo "└──────────────────────────────────────────────┘"
            echo ""
            return
        fi
        sleep 0.5
    done
    echo "Timeout waiting for pairing code. Please check zeroclaw.log"
}

# Function to stop
stop() {
    if pgrep -f "$BINARY" > /dev/null; then
        pkill -f "$BINARY"
        echo "ZeroClaw stopped."
    else
        echo "ZeroClaw is not running."
    fi
}

# Function to status
status() {
    if pgrep -f "$BINARY" > /dev/null; then
        echo "ZeroClaw is running."
    else
        echo "ZeroClaw is stopped."
    fi
}

case "$1" in
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
    status)
        status
        ;;
    *)
        echo "Usage: $0 {start|stop|restart|status}"
        exit 1
        ;;
esac
