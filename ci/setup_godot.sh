#!/usr/bin/env bash
# Ставит Godot (и при NEED_TEMPLATES=1 — шаблоны экспорта) прямо с GitHub.
# Без аккаунтов и лицензий. Скачанное кэшируется в ~/.cache/godot-dl.
set -euo pipefail

V="${GODOT_VERSION:-4.7.2}"
DL="$HOME/.cache/godot-dl/$V"
BASE="https://github.com/godotengine/godot/releases/download/${V}-stable"
mkdir -p "$DL" "$HOME/godot-bin"

if [ ! -f "$DL/godot.zip" ]; then
  echo "Скачиваю Godot $V…"
  curl -fsSL --retry 3 -o "$DL/godot.zip" "$BASE/Godot_v${V}-stable_linux.x86_64.zip"
fi
unzip -q -o "$DL/godot.zip" -d "$HOME/godot-bin"
BIN="$HOME/godot-bin/Godot_v${V}-stable_linux.x86_64"
chmod +x "$BIN"
if [ -w /usr/local/bin ]; then ln -sf "$BIN" /usr/local/bin/godot; else sudo ln -sf "$BIN" /usr/local/bin/godot; fi

if [ "${NEED_TEMPLATES:-0}" = "1" ]; then
  if [ ! -f "$DL/templates.tpz" ]; then
    echo "Скачиваю шаблоны экспорта Godot $V (около 1,3 ГБ)…"
    curl -fsSL --retry 3 -o "$DL/templates.tpz" "$BASE/Godot_v${V}-stable_export_templates.tpz"
  fi
  T="$HOME/.local/share/godot/export_templates/${V}.stable"
  mkdir -p "$T"
  TMP="$(mktemp -d)"
  unzip -q -o "$DL/templates.tpz" -d "$TMP"
  cp -r "$TMP"/templates/* "$T/"
  rm -rf "$TMP"
fi

godot --headless --version
