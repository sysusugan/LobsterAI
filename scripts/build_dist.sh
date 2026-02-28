#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RELEASE_DIR="$ROOT_DIR/release"

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

if nvm use lts/krypton >/dev/null 2>&1; then
  echo "已切换到 Node: lts/krypton"
elif [[ -f "$ROOT_DIR/.nvmrc" ]]; then
  nvm use >/dev/null
  echo "lts/krypton 不可用，已回退到 .nvmrc"
else
  echo "无法切换到 lts/krypton，且未找到 .nvmrc。"
  exit 1
fi

cd "$ROOT_DIR"
echo "开始打包: npm run dist:mac:arm64"
npm run dist:mac:arm64

if [[ -d "$RELEASE_DIR" ]]; then
  echo "打包完成，打开目录: $RELEASE_DIR"
  open "$RELEASE_DIR"
else
  echo "打包完成，但未找到 release 目录: $RELEASE_DIR"
fi
