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
LOG_FILE="$RUN_DIR/electron-dev.log"

mkdir -p "$RUN_DIR"

if [[ -f "$PID_FILE" ]]; then
  OLD_PID="$(cat "$PID_FILE" 2>/dev/null || true)"
  if [[ -n "${OLD_PID:-}" ]] && kill -0 "$OLD_PID" 2>/dev/null; then
    echo "electron:dev 已在运行 (PID: $OLD_PID)"
    echo "日志文件: $LOG_FILE"
    exit 0
  fi
  rm -f "$PID_FILE"
fi

NVM_DIR="${NVM_DIR:-$HOME/.nvm}"
NVM_CANDIDATES=(
  "$NVM_DIR/nvm.sh"
  "/usr/local/opt/nvm/nvm.sh"
  "/opt/homebrew/opt/nvm/nvm.sh"
)

NVM_SH=''
for candidate in "${NVM_CANDIDATES[@]}"; do
  if [[ -s "$candidate" ]]; then
    NVM_SH="$candidate"
    break
  fi
done

if [[ -z "$NVM_SH" ]]; then
  echo "未找到 nvm.sh，请先安装 nvm 或设置 NVM_DIR。"
  exit 1
fi

# shellcheck disable=SC1090
source "$NVM_SH"

if ! nvm use lts/krypton >/dev/null 2>&1; then
  if [[ -f "$ROOT_DIR/.nvmrc" ]]; then
    nvm use >/dev/null
  else
    echo "无法切换到 lts/krypton，且未找到 .nvmrc。"
    exit 1
  fi
fi

cd "$ROOT_DIR"
nohup npm run electron:dev >"$LOG_FILE" 2>&1 &
PID=$!
echo "$PID" >"$PID_FILE"

echo "已启动 electron:dev (PID: $PID)"
echo "日志文件: $LOG_FILE"
echo "停止命令: bash $ROOT_DIR/scripts/stop_all.sh"
