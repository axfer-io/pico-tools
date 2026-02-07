# Pico Toolchain Setup

Embedded systems · Control · Debugging ⚙️  
Firmware workflows that actually run 🚀

---

## Overview

This document describes the **complete toolchain setup** used for Raspberry Pi Pico
(RP2040 / RP2350) firmware development.

It installs:
- Pico SDK + extras
- ARM GCC toolchain
- OpenOCD (Raspberry Pi fork)
- picotool
- Personal tooling (`pico-tools`)

The setup is designed to be:
- Reproducible
- Portable across machines
- Compatible with CMake Presets + Ninja
- Friendly to Debug Probe / SWD workflows (no BOOTSEL)

---

## Supported Boards

- Raspberry Pi Pico (RP2040)
- Raspberry Pi Pico W (RP2040 + Wi-Fi)
- Raspberry Pi Pico 2 (RP2350)
- Raspberry Pi Pico 2 W (RP2350 + Wi-Fi)

---

## Requirements

- Pop!_OS / Ubuntu / Debian-based Linux
- sudo privileges
- Internet connection

---

## Installation (One Command)

Clone your firmware or tools repository, then run:

```bash
chmod +x install.sh
./install.sh
```

This script will:
- Install system dependencies
- Clone Pico SDK repositories
- Build and install picotool
- Build and install OpenOCD (Raspberry Pi fork)
- Clone `pico-tools` into `~/pico/tools`
- Configure environment variables

---

## Installed Layout

After installation, you should have:

```text
~/pico/
├── pico-sdk
├── pico-extras
├── pico-playground
├── pico-examples
├── picotool
├── openocd
└── tools/
    ├── flash.sh
    ├── pico-openocd.sh
    └── README.md
```

---

## Environment Variables

The installer adds the following to `~/.bashrc`:

```bash
export PICO_SDK_PATH="$HOME/pico/pico-sdk"
export PICO_EXAMPLES_PATH="$HOME/pico/pico-examples"
export PICO_EXTRAS_PATH="$HOME/pico/pico-extras"
export PICO_PLAYGROUND_PATH="$HOME/pico/pico-playground"
export PATH="$HOME/pico/tools:$PATH"
```

Reload your shell after installation:

```bash
source ~/.bashrc
```

---

## Verification Checklist

Run the following commands to verify the setup:

```bash
cmake --version
ninja --version
arm-none-eabi-gcc --version
openocd --version
picotool version
```

All commands should execute without errors.

---

## Typical Workflow

### 1) Configure a build preset (once)

```bash
cmake --preset pico2w-debug
```

### 2) Build + flash (daily loop)

```bash
cmake --build --preset flash-pico2w-debug
```

### 3) Start OpenOCD for debugging

```bash
pico-openocd.sh
```

Attach using:
- `gdb-multiarch`
- Neovim + nvim-dap
- Any GDB frontend

---

## Design Principles

- Tooling lives outside firmware repos
- Firmware templates stay clean
- Debug via SWD, not mass-storage hacks
- Explicit configuration over magic

If your workflow requires BOOTSEL, something is missing.

---

## Author

**axfer-io**  
Embedded systems · Control · Debugging

---

## License

MIT
