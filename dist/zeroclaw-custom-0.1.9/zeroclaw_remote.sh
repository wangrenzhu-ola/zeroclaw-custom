#!/bin/bash
# Remote ZeroClaw Control Script

APP_DIR="$HOME/.zeroclaw"
BIN_DIR="$HOME/.cargo/bin"

# Function to start
start() {
    if pgrep -f "$BIN_DIR/zeroclaw" > /dev/null; then
        echo "    ZeroClaw is already running."
        exit 1
    fi
    
    echo "    Starting ZeroClaw..."
    
    # Run in background
    if [ ! -z "${MINIMAX_API_KEY}" ]; then
        echo "    Configuring MiniMax key..."
        export MINIMAX_API_KEY="${MINIMAX_API_KEY}"
        export GROUP_ID="1886252427301937152"
    fi
    
    nohup "$BIN_DIR/zeroclaw" gateway > "$APP_DIR/zeroclaw.log" 2>&1 &
    echo "    ZeroClaw started. Log: $APP_DIR/zeroclaw.log"
    echo "    Waiting for Pairing Code..."
    # Wait up to 10 seconds for the code to appear
    for i in {1..20}; do
        if grep -q "X-Pairing-Code:" "$APP_DIR/zeroclaw.log"; then
            CODE=$(grep "X-Pairing-Code:" "$APP_DIR/zeroclaw.log" | tail -n1 | awk '{print $NF}')
            echo ""
            echo "    ┌──────────────────────────────────────────────┐"
            echo "    │  🔑 Remote Pairing Code: $CODE              │"
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
    if pgrep -f "$BIN_DIR/zeroclaw" > /dev/null; then
        pkill -f "$BIN_DIR/zeroclaw"
        echo "    ZeroClaw stopped."
    else
        echo "    ZeroClaw is not running."
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
    *)
        echo "Usage: $0 {start|stop|restart}"
        exit 1
        ;;
esac
