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

check_gdb() {
  if command -v arm-none-eabi-gdb >/dev/null 2>&1; then
    ok "arm-none-eabi-gdb found: $(command -v arm-none-eabi-gdb)"
  elif command -v gdb >/dev/null 2>&1; then
    ok "gdb found: $(command -v gdb)"
    warn "arm-none-eabi-gdb not found, but host gdb exists"
  else
    fail "arm-none-eabi-gdb or gdb not found"
  fi
}

echo "== Pico Toolchain Doctor - Fedora =="

check_cmd git
check_cmd cmake
check_cmd ninja
check_cmd arm-none-eabi-gcc
check_gdb
check_cmd openocd
check_cmd picotool

echo
echo "== Versions =="
cmake --version | head -n 1 || true
ninja --version || true
arm-none-eabi-gcc --version | head -n 1 || true
if command -v arm-none-eabi-gdb >/dev/null 2>&1; then
  arm-none-eabi-gdb --version | head -n 1 || true
elif command -v gdb >/dev/null 2>&1; then
  gdb --version | head -n 1 || true
fi
openocd --version | head -n 1 || true
picotool version || true

echo
echo "== Env Vars =="
[[ -n "${PICO_SDK_PATH:-}" ]] && ok "PICO_SDK_PATH=$PICO_SDK_PATH" || warn "PICO_SDK_PATH not set"
[[ -d "${PICO_SDK_PATH:-/nope}" ]] && ok "PICO_SDK_PATH exists" || warn "PICO_SDK_PATH directory missing"

[[ -n "${PICO_EXAMPLES_PATH:-}" ]] && ok "PICO_EXAMPLES_PATH=$PICO_EXAMPLES_PATH" || warn "PICO_EXAMPLES_PATH not set"
[[ -d "${PICO_EXAMPLES_PATH:-/nope}" ]] && ok "PICO_EXAMPLES_PATH exists" || warn "PICO_EXAMPLES_PATH directory missing"

[[ -n "${PICO_EXTRAS_PATH:-}" ]] && ok "PICO_EXTRAS_PATH=$PICO_EXTRAS_PATH" || warn "PICO_EXTRAS_PATH not set"
[[ -d "${PICO_EXTRAS_PATH:-/nope}" ]] && ok "PICO_EXTRAS_PATH exists" || warn "PICO_EXTRAS_PATH directory missing"

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
echo "== udev rules =="
if [[ -f /etc/udev/rules.d/99-pico-debug.rules ]]; then
  ok "/etc/udev/rules.d/99-pico-debug.rules exists"
else
  warn "udev rules missing: /etc/udev/rules.d/99-pico-debug.rules"
fi

if groups "$USER" | grep -qw plugdev; then
  ok "User $USER is in plugdev group"
else
  warn "User $USER is not in plugdev group; log out/in if you just added it"
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
echo "== USB probes/devices =="
if command -v lsusb >/dev/null 2>&1; then
  if lsusb | grep -Ei "cmsis|dap|raspberry|pico|2e8a|0d28" >/dev/null; then
    ok "Found possible probe/device in lsusb"
    lsusb | grep -Ei "cmsis|dap|raspberry|pico|2e8a|0d28" || true
  else
    warn "No obvious probe/device found in lsusb"
    warn "Connect Debug Probe or Pico in BOOTSEL mode to test USB detection"
  fi
else
  warn "lsusb not installed; install usbutils"
fi

echo
ok "Doctor completed."
