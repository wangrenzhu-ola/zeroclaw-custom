#!/usr/bin/env bash
set -euo pipefail

REMOTE_HOST="${REMOTE_HOST:-154.9.254.212}"
REMOTE_USER="${REMOTE_USER:-root}"
LOCAL_PORT="${LOCAL_PORT:-42618}"
REMOTE_PORT="${REMOTE_PORT:-42617}" # ZeroClaw Gateway default port
# ZeroClaw doesn't have a separate dashboard port by default, it serves UI on the same port usually
# But if it does, add it here. Assuming just Gateway API/UI on one port.

PID_FILE="${PID_FILE:-$HOME/.zeroclaw_tunnel.pid}"
LOG_FILE="${LOG_FILE:-$HOME/.zeroclaw_tunnel.log}"
SSH_TEST_LOG="${SSH_TEST_LOG:-$HOME/.zeroclaw_ssh_test.log}"
SSH_PASSWORD="i3mNVmjqfaSNYXa9"
SSH_IDENTITY_FILE="${SSH_IDENTITY_FILE:-}"

cmd="${1:-start}"

ensure_autossh() {
  if ! command -v autossh >/dev/null 2>&1; then
    echo "autossh 未安装，请先执行：brew install autossh"
    exit 1
  fi
}

ensure_ssh() {
  if ! command -v ssh >/dev/null 2>&1; then
    echo "ssh 不可用，请先安装 OpenSSH 客户端"
    exit 1
  fi
}

ensure_sshpass() {
  if ! command -v sshpass >/dev/null 2>&1; then
    echo "检测到使用 SSH 密码认证，但 sshpass 未安装"
    echo "请先执行：brew install hudochenkov/sshpass/sshpass"
    exit 1
  fi
}

ensure_lsof() {
  if ! command -v lsof >/dev/null 2>&1; then
    echo "lsof 不可用，无法检查端口占用"
    exit 1
  fi
}

port_in_use() {
  lsof -nP -iTCP:"$LOCAL_PORT" -sTCP:LISTEN >/dev/null 2>&1
}

test_ssh_auth() {
  ensure_ssh
  if [[ -n "$SSH_PASSWORD" ]]; then
    ensure_sshpass
    if sshpass -p "$SSH_PASSWORD" ssh \
      -o PreferredAuthentications=password \
      -o PubkeyAuthentication=no \
      -o NumberOfPasswordPrompts=1 \
      -o ConnectTimeout=8 \
      -o StrictHostKeyChecking=accept-new \
      "${REMOTE_USER}@${REMOTE_HOST}" "exit 0" \
      >"$SSH_TEST_LOG" 2>&1; then
      return 0
    fi
    return 1
  fi
  # ... (Identity file check skipped for brevity if password used, but kept structure)
  if ssh \
    -o BatchMode=yes \
    -o ConnectTimeout=8 \
    -o StrictHostKeyChecking=accept-new \
    "${REMOTE_USER}@${REMOTE_HOST}" "exit 0" \
    >"$SSH_TEST_LOG" 2>&1; then
    return 0
  fi
  return 1
}

wait_tunnel_ready() {
  local i
  for i in {1..12}; do
    if port_in_use; then
      return 0
    fi
    sleep 1
  done
  return 1
}

is_running() {
  if [[ -f "$PID_FILE" ]]; then
    local pid
    pid="$(cat "$PID_FILE" 2>/dev/null || true)"
    if [[ -n "${pid:-}" ]] && kill -0 "$pid" >/dev/null 2>&1; then
      return 0
    fi
  fi
  return 1
}

start_tunnel() {
  ensure_autossh
  ensure_lsof
  if is_running; then
    echo "隧道已在运行，PID=$(cat "$PID_FILE")"
    print_url
    exit 0
  fi
  if ! test_ssh_auth; then
    echo "SSH 认证失败，无法建立隧道。详情见：$SSH_TEST_LOG"
    cat "$SSH_TEST_LOG" || true
    exit 1
  fi
  if port_in_use; then
    echo "本地端口 ${LOCAL_PORT} 已被占用，请先释放后重试"
    lsof -nP -iTCP:"$LOCAL_PORT" -sTCP:LISTEN || true
    exit 1
  fi

  echo "启动隧道..."
  if [[ -n "$SSH_PASSWORD" ]]; then
    sshpass -p "$SSH_PASSWORD" ssh -f -N \
      -L "${LOCAL_PORT}:127.0.0.1:${REMOTE_PORT}" \
      -o PreferredAuthentications=password \
      -o PubkeyAuthentication=no \
      -o NumberOfPasswordPrompts=1 \
      -o ConnectTimeout=8 \
      -o ExitOnForwardFailure=yes \
      -o ServerAliveInterval=30 \
      -o ServerAliveCountMax=3 \
      -o TCPKeepAlive=yes \
      -o StrictHostKeyChecking=accept-new \
      "${REMOTE_USER}@${REMOTE_HOST}" \
      >>"$LOG_FILE" 2>&1
  else
      # Autossh path
      AUTOSSH_GATETIME=0 AUTOSSH_POLL=30 AUTOSSH_FIRST_POLL=30 AUTOSSH_LOGFILE="$LOG_FILE" \
      autossh -M 0 -f -N \
        -L "${LOCAL_PORT}:127.0.0.1:${REMOTE_PORT}" \
        -o BatchMode=yes \
        -o ConnectTimeout=8 \
        -o ExitOnForwardFailure=yes \
        -o ServerAliveInterval=30 \
        -o ServerAliveCountMax=3 \
        -o TCPKeepAlive=yes \
        -o StrictHostKeyChecking=accept-new \
        "${REMOTE_USER}@${REMOTE_HOST}"
  fi

  local pid
  # Wait a bit for ssh to fork
  sleep 2
  # Find the ssh process (not autossh wrapper if possible, or just pgrep)
  # Using pgrep for the specific port forward
  pid="$(pgrep -f "ssh.*-L ${LOCAL_PORT}:127.0.0.1:${REMOTE_PORT}.*${REMOTE_USER}@${REMOTE_HOST}" | tail -n 1 || true)"
  
  if [[ -z "${pid:-}" ]]; then
    echo "启动失败，请查看日志：$LOG_FILE"
    exit 1
  fi
  if ! wait_tunnel_ready; then
    echo "隧道启动后端口未就绪，请查看日志：$LOG_FILE"
    tail -n 20 "$LOG_FILE" || true
    exit 1
  fi
  echo "$pid" >"$PID_FILE"
  echo "已启动后台隧道，PID=$pid"
  print_url
}

stop_tunnel() {
  if ! is_running; then
    rm -f "$PID_FILE"
    echo "隧道未运行"
    exit 0
  fi
  local pid
  pid="$(cat "$PID_FILE")"
  kill "$pid" >/dev/null 2>&1 || true
  sleep 1
  pkill -f "autossh.*-L ${LOCAL_PORT}:127.0.0.1:${REMOTE_PORT}" >/dev/null 2>&1 || true
  pkill -f "ssh.*-L ${LOCAL_PORT}:127.0.0.1:${REMOTE_PORT}.*${REMOTE_USER}@${REMOTE_HOST}" >/dev/null 2>&1 || true
  rm -f "$PID_FILE"
  echo "隧道已停止"
}

status_tunnel() {
  if is_running; then
    echo "运行中，PID=$(cat "$PID_FILE")"
    print_url
  else
    echo "未运行"
    exit 1
  fi
}

print_url() {
  echo "ZeroClaw API: http://127.0.0.1:${LOCAL_PORT}"
  echo "ZeroClaw UI : http://127.0.0.1:${LOCAL_PORT}/ (if bundled)"
}

case "$cmd" in
  start)
    start_tunnel
    ;;
  stop)
    stop_tunnel
    ;;
  restart)
    stop_tunnel || true
    start_tunnel
    ;;
  status)
    status_tunnel
    ;;
  url)
    print_url
    ;;
  *)
    echo "用法: $0 {start|stop|restart|status|url}"
    exit 1
    ;;
esac
