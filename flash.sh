#!/usr/bin/env bash
set -euo pipefail

# -------- Config SWD por variable de entorno --------
: "${PICO_SWD:=DEBUGPROBE}"   # DEBUGPROBE | PICOPROBE | RPI

# -------- Resolver ELF --------
# 1) Si pasas ruta como argumento, úsala.
# 2) Si no, busca el .elf más reciente en ./build/ o ./ (último modificado).

elf="${1:-}"

if [[ -z "$elf" ]]; then
  # habilita nullglob para que *.elf vacío no quede literal
  shopt -s nullglob
  candidates=()
  # Prioriza build/
  if [[ -d build ]]; then
    while IFS= read -r -d '' f; do candidates+=("$f"); done < <(find build -maxdepth 2 -name "*.elf" -print0)
  fi
  # Si no hay en build, busca en el dir actual
  if [[ ${#candidates[@]} -eq 0 ]]; then
    while IFS= read -r -d '' f; do candidates+=("$f"); done < <(find . -maxdepth 1 -name "*.elf" -print0)
  fi
  shopt -u nullglob
  if [[ ${#candidates[@]} -eq 0 ]]; then
    echo "❌ No se encontró ningún .elf (pásalo como argumento: ./flash.sh path/to/app.elf)"
    exit 1
  fi
  # Toma el más reciente
  IFS=$'\n' read -r -d '' -a sorted < <(ls -1t "${candidates[@]}" && printf '\0')
  elf="${sorted[0]}"
fi

elf="$(realpath "$elf")"

# -------- Elegir interfaz y velocidad --------
interface="cmsis-dap.cfg"
speed="5000"

case "$PICO_SWD" in
  RPI)
    # interface="raspberrypi-swd.cfg"   # alternativa
    interface="raspberrypi-native.cfg"
    speed="1000"
    ;;
  PICOPROBE)
    interface="picoprobe.cfg"
    ;;
  DEBUGPROBE|*)
    interface="cmsis-dap.cfg"
    ;;
esac


# -------- Detectar target rp2040 vs rp2350 --------
target="rp2040.cfg"

# Primero intentar con picotool (si está disponible)
if command -v picotool >/dev/null 2>&1; then
  if picotool info "$elf" 2>/dev/null | grep -q "RP2350"; then
    target="rp2350.cfg"
  fi
fi

# Fallback: intentar con readelf
if [[ "$target" == "rp2040.cfg" ]] && command -v readelf >/dev/null 2>&1; then
  if readelf -A "$elf" 2>/dev/null | grep -qi "rp2350"; then
    target="rp2350.cfg"
  fi
fi

# Fallback extra: intentar con strings
if [[ "$target" == "rp2040.cfg" ]] && command -v strings >/dev/null 2>&1; then
  if strings "$elf" | grep -qi "rp2350"; then
    target="rp2350.cfg"
  fi
fi




# -------- Localizar OpenOCD --------
# 1) Preferir el de ~/.pico-sdk si existe
# 2) Si no, usar el del PATH
OPENOCD_BIN=""
OPENOCD_TCL=""

if [[ -d "$HOME/.pico-sdk/openocd" ]]; then
  # coge la versión más reciente dentro de ~/.pico-sdk/openocd/
  latest_dir="$(ls -1d "$HOME/.pico-sdk/openocd"/* 2>/dev/null | sort -V | tail -n1 || true)"
  if [[ -n "$latest_dir" && -x "$latest_dir/openocd" ]]; then
    OPENOCD_BIN="$latest_dir/openocd"
    # scripts/tcl dir
    if [[ -d "$latest_dir/scripts" ]]; then
      OPENOCD_TCL="$latest_dir/scripts"
    elif [[ -d "$latest_dir/tcl" ]]; then
      OPENOCD_TCL="$latest_dir/tcl"
    fi
  fi
fi

# fallback: el openocd del PATH + tcl desde el SDK si existe
if [[ -z "$OPENOCD_BIN" ]]; then
  if command -v openocd >/dev/null 2>&1; then
    OPENOCD_BIN="$(command -v openocd)"
  fi
fi

if [[ -z "$OPENOCD_TCL" ]]; then
  # intenta con el openocd del SDK (pico-sdk repo paralelo)
  if [[ -n "${PICO_SDK_PATH:-}" && -d "$PICO_SDK_PATH/../openocd/tcl" ]]; then
    OPENOCD_TCL="$PICO_SDK_PATH/../openocd/tcl"
  elif [[ -d "$HOME/pico/openocd/tcl" ]]; then
    OPENOCD_TCL="$HOME/pico/openocd/tcl"
  fi
fi

# Comprobaciones
if [[ -z "$OPENOCD_BIN" ]]; then
  echo "❌ openocd no encontrado. Instálalo o usa el de ~/.pico-sdk"
  exit 1
fi
if [[ -z "$OPENOCD_TCL" ]]; then
  echo "❌ No se encontró la carpeta de scripts TCL de OpenOCD."
  echo "   Prueba configurando PICO_SDK_PATH o instala el paquete OpenOCD del SDK."
  exit 1
fi

echo "▶️  ELF:        $elf"
echo "🔌 Interface:  $interface"
echo "🎯 Target:     $target"
echo "⚡ Speed:      $speed kHz"
echo "🧰 OpenOCD:    $OPENOCD_BIN"
echo "📚 TCL path:   $OPENOCD_TCL"

# -------- Programar --------
"$OPENOCD_BIN" -s "$OPENOCD_TCL" \
  -f "interface/$interface" \
  -f "target/$target" \
  -c "adapter speed $speed" \
  -c "program \"$elf\" verify reset exit"

echo "✅ Deployed"
if command -v arm-none-eabi-size >/dev/null 2>&1; then
  arm-none-eabi-size "$elf" || true
fi
