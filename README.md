# pico-tools

Embedded systems · Control · Debugging ⚙️  
I/O 🔌, firmware 🔧, and systems that actually run 🚀

---

## Overview

This repository contains **personal tooling** used for embedded firmware development
with the Raspberry Pi Pico SDK.

These tools are intentionally kept **outside firmware templates** to keep projects
clean and focused, while still enabling a fast and repeatable **build / flash / debug**
workflow.

---

## Tools Included

### `flash.sh`

Firmware flashing helper using **OpenOCD + SWD**.

- Automatically resolves the most recent `.elf` from `build/`
- Programs via debug probe (no BOOTSEL)
- Designed to be called from CMake as a custom target

Typical usage (manual):
```bash
~/pico/tools/flash.sh path/to/firmware.elf
```

Typical usage (via CMake):
```bash
cmake --build --target flash
```

Expected location:
```text
~/pico/tools/flash.sh
```

---

### `pico-openocd.sh`

OpenOCD launcher for **debug sessions**.

- Starts OpenOCD with correct interface and target
- Auto-detects RP2040 vs RP2350 when possible
- Exposes standard ports:
  - GDB: `:3333`
  - Telnet: `:4444`
  - TCL: `:6666`

Typical usage:
```bash
pico-openocd.sh
```

This script is intended to be used alongside:
- `gdb-multiarch`
- Neovim + nvim-dap
- Any standard GDB frontend

---

# Serial monitor
./pico-serial.sh
This script is intented to facilite the open a serial monitor in the terminal

---

## Expected Directory Layout

The tools are expected to live at a fixed location:

```text
~/pico/tools/
├── flash.sh
├── pico-openocd.sh
└── README.md
```

Firmware projects reference these tools via absolute paths or environment variables.

---

## Integration with Firmware Projects

Example CMake integration:

```cmake
set(PICO_FLASH_SCRIPT "$ENV{HOME}/pico/tools/flash.sh")

if(EXISTS "${PICO_FLASH_SCRIPT}")
  add_custom_target(flash
    COMMAND ${PICO_FLASH_SCRIPT} $<TARGET_FILE:${FW_NAME}>
    DEPENDS ${FW_NAME}
    USES_TERMINAL
  )
endif()
```

If the tools are not present, the firmware project will still build normally;
only the `flash` target will be disabled.

---

## Design Philosophy

- Keep firmware repositories clean
- Keep tooling reusable and centralized
- Prefer explicit control over hidden automation
- Debug on real hardware, not simulations

If flashing or debugging requires BOOTSEL or guesswork, the workflow is incomplete.

---

## Documentation

- 🛠️ [Troubleshooting](README_TROUBLESHOOT.md)
- 🩺 `doctor.sh` – automated environment check

## Install

Use the system installer:

➡️ https://github.com/axfer-io/pico-bootstrap


## Author

**axfer-io**  
Embedded systems · Control · Debugging

---

## License

MIT
