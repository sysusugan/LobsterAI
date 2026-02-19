#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

resolve_run_dir() {
  if [[ "${OSTYPE:-}" == darwin* ]]; then
    echo "$HOME/Library/Logs/LobsterAI/dev-run"
    return
  fi

  if [[ -n "${XDG_STATE_HOME:-}" ]]; then
    echo "$XDG_STATE_HOME/lobsterai/dev-run"
    return
  fi

  echo "$HOME/.lobsterai/dev-run"
}

RUN_DIR="$(resolve_run_dir)"
PID_FILE="$RUN_DIR/electron-dev.pid"

kill_tree() {
  local pid="$1"
  local children
  children="$(pgrep -P "$pid" || true)"
  if [[ -n "$children" ]]; then
    while IFS= read -r child; do
      [[ -n "$child" ]] && kill_tree "$child"
    done <<<"$children"
  fi
  kill -TERM "$pid" 2>/dev/null || true
}

force_kill_if_alive() {
  local pid="$1"
  if kill -0 "$pid" 2>/dev/null; then
    kill -KILL "$pid" 2>/dev/null || true
  fi
}

stopped_any=0

if [[ -f "$PID_FILE" ]]; then
  PID="$(cat "$PID_FILE" 2>/dev/null || true)"
  if [[ -n "${PID:-}" ]] && kill -0 "$PID" 2>/dev/null; then
    kill_tree "$PID"
    sleep 2
    force_kill_if_alive "$PID"
    stopped_any=1
    echo "已停止脚本启动的进程 (PID: $PID)"
  fi
  rm -f "$PID_FILE"
fi

if command -v lsof >/dev/null 2>&1; then
  PORT_PIDS="$(lsof -ti tcp:5175 -sTCP:LISTEN 2>/dev/null || true)"
  if [[ -n "$PORT_PIDS" ]]; then
    while IFS= read -r p; do
      [[ -n "$p" ]] || continue
      kill -TERM "$p" 2>/dev/null || true
      sleep 1
      force_kill_if_alive "$p"
      stopped_any=1
      echo "已停止 5175 端口进程 (PID: $p)"
    done <<<"$PORT_PIDS"
  fi
fi

EXTRA_PIDS="$(
  pgrep -f "$ROOT_DIR.*npm run electron:dev|$ROOT_DIR.*vite --port 5175|$ROOT_DIR.*wait-on -v -t 120000 -d 10000 http://localhost:5175|$ROOT_DIR.*cross-env NODE_ENV=development ELECTRON_START_URL=http://localhost:5175 electron \\.|$ROOT_DIR/SKILLs/web-search" || true
)"

if [[ -n "$EXTRA_PIDS" ]]; then
  while IFS= read -r p; do
    [[ -n "$p" ]] || continue
    kill -TERM "$p" 2>/dev/null || true
    sleep 1
    force_kill_if_alive "$p"
    stopped_any=1
    echo "已停止相关进程 (PID: $p)"
  done <<<"$EXTRA_PIDS"
fi

if [[ "$stopped_any" -eq 0 ]]; then
  echo "未发现需要停止的进程。"
else
  echo "停止完成。"
fi
