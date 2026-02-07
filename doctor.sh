#!/usr/bin/env bash
set -euo pipefail

ok()   { printf "✅ %s\n" "$1"; }
warn() { printf "⚠️  %s\n" "$1"; }
fail() { printf "❌ %s\n" "$1"; exit 1; }

check_cmd() {
  local c="$1"
  if command -v "$c" >/dev/null 2>&1; then
    ok "$c found: $(command -v "$c")"
  else
    fail "$c not found"
  fi
}

echo "== Pico Toolchain Doctor =="

check_cmd git
check_cmd cmake
check_cmd ninja
check_cmd arm-none-eabi-gcc
check_cmd gdb-multiarch
check_cmd openocd
check_cmd picotool

echo
echo "== Env Vars =="
[[ -n "${PICO_SDK_PATH:-}" ]] && ok "PICO_SDK_PATH=$PICO_SDK_PATH" || warn "PICO_SDK_PATH not set"
[[ -d "${PICO_SDK_PATH:-/nope}" ]] && ok "PICO_SDK_PATH exists" || warn "PICO_SDK_PATH directory missing"

echo
echo "== OpenOCD scripts =="
if [[ -d /usr/local/share/openocd/scripts ]]; then
  ok "/usr/local/share/openocd/scripts exists"
elif [[ -d /usr/share/openocd/scripts ]]; then
  ok "/usr/share/openocd/scripts exists"
else
  warn "OpenOCD scripts not found in /usr/local/share or /usr/share"
fi

echo
echo "== pico-tools =="
TOOLS_DIR="${HOME}/pico/tools"
if [[ -d "$TOOLS_DIR" ]]; then
  ok "$TOOLS_DIR exists"
  [[ -x "$TOOLS_DIR/flash.sh" ]] && ok "flash.sh executable" || warn "flash.sh missing or not executable"
  [[ -x "$TOOLS_DIR/pico-openocd.sh" ]] && ok "pico-openocd.sh executable" || warn "pico-openocd.sh missing or not executable"
else
  warn "$TOOLS_DIR missing"
fi

echo
echo "== USB probes (lsusb) =="
if command -v lsusb >/dev/null 2>&1; then
  lsusb | grep -Ei "cmsis|dap|raspberry|pico|2e8a|0d28" >/dev/null && ok "Found possible probe/device in lsusb" || warn "No obvious probe/device found in lsusb"
else
  warn "lsusb not installed (install usbutils)"
fi

echo
ok "Doctor completed."
