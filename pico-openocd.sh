#!/usr/bin/env bash
set -euo pipefail

PICO_SWD="${PICO_SWD:-DEBUGPROBE}"
PROJ_DIR="${PROJ_DIR:-$PWD}"

# -------- Resolver ELF --------
if [[ $# -ge 1 ]]; then
  ELF="$(realpath "$1")"
else
  mapfile -t ELFS < <(find "$PROJ_DIR/build" -type f -name "*.elf" -print 2>/dev/null | sort -u)
  if [[ ${#ELFS[@]} -eq 0 ]]; then
    echo "❌ No encontré ningún .elf en: $PROJ_DIR/build/**"
    echo "   Compila primero o pasa la ruta como argumento:"
    echo "   $0 /ruta/a/tu.elf"
    exit 1
  fi
  ELF="$(ls -1t "${ELFS[@]}" | head -n 1)"
  ELF="$(realpath "$ELF")"
fi

echo "PICO_SWD=$PICO_SWD"
echo "ELF=$ELF"

# -------- Interfaz SWD --------
interface="cmsis-dap.cfg"
speed="1000"

case "$PICO_SWD" in
  RPI)
    interface="raspberrypi-native.cfg"
    speed="1000"
    ;;
  PICOPROBE)
    interface="picoprobe.cfg"
    speed="1000"
    ;;
  DEBUGPROBE)
    interface="cmsis-dap.cfg"
    speed="1000"
    ;;
  *)
    echo "❌ PICO_SWD inválido: $PICO_SWD (usa RPI|PICOPROBE|DEBUGPROBE)"
    exit 1
    ;;
esac

# -------- Detectar target (rp2040 vs rp2350) --------
target="rp2350.cfg"   # default razonable si estás en Pico 2
detected="unknown"

# 1) picotool (mejor)
if command -v picotool >/dev/null 2>&1; then
  info="$(picotool info "$ELF" 2>/dev/null || true)"
  if echo "$info" | grep -q "RP2040"; then
    target="rp2040.cfg"
    detected="RP2040"
  elif echo "$info" | grep -q "RP2350"; then
    target="rp2350.cfg"
    detected="RP2350"
  fi
fi

# 2) fallback: strings/readelf si no se detectó
if [[ "$detected" == "unknown" ]]; then
  if command -v strings >/dev/null 2>&1; then
    if strings "$ELF" | grep -qi "rp2040"; then
      target="rp2040.cfg"
      detected="RP2040(strings)"
    elif strings "$ELF" | grep -qi "rp2350"; then
      target="rp2350.cfg"
      detected="RP2350(strings)"
    fi
  fi
fi

if [[ "$detected" == "unknown" ]] && command -v readelf >/dev/null 2>&1; then
  if readelf -A "$ELF" 2>/dev/null | grep -qi "rp2040"; then
    target="rp2040.cfg"
    detected="RP2040(readelf)"
  elif readelf -A "$ELF" 2>/dev/null | grep -qi "rp2350"; then
    target="rp2350.cfg"
    detected="RP2350(readelf)"
  fi
fi

if [[ "$detected" == "unknown" ]]; then
  echo "⚠️  No pude detectar RP2040/RP2350 desde el ELF. Usando default: $target"
else
  echo "✅ Detected: $detected -> target/$target"
fi

echo "Interface=$interface"
echo "Target=$target"
echo "Speed=${speed}kHz"

# -------- OpenOCD scripts path --------
OPENOCD_SCRIPTS="/usr/local/share/openocd/scripts"
if [[ ! -d "$OPENOCD_SCRIPTS" ]]; then
  OPENOCD_SCRIPTS="/usr/share/openocd/scripts"
fi
if [[ ! -d "$OPENOCD_SCRIPTS" ]]; then
  echo "❌ No encontré scripts de OpenOCD en /usr/local/share/openocd/scripts ni /usr/share/openocd/scripts"
  exit 1
fi

# -------- OpenOCD (GDB server) --------
exec openocd \
  -s "$OPENOCD_SCRIPTS" \
  -f "interface/${interface}" \
  -f "target/${target}" \
  -c "transport select swd" \
  -c "adapter speed ${speed}" \
  -c "gdb_port 3333" \
  -c "tcl_port 6666" \
  -c "telnet_port 4444"
