## Troubleshooting

### 1) `cmake` says: “unable to find a build program corresponding to Ninja”
Install Ninja:

```bash
sudo apt install ninja-build
```

Verify:

```bash
ninja --version
```

---

### 2) OpenOCD can’t see the Debug Probe / CMSIS-DAP
Check USB:

```bash
lsusb
```

If permissions are the issue, add a udev rule:

```bash
sudo tee /etc/udev/rules.d/60-cmsis-dap.rules >/dev/null <<'EOF'
SUBSYSTEM=="usb", ATTR{idVendor}=="0d28", ATTR{idProduct}=="0204", MODE="0666"
SUBSYSTEM=="usb", ATTR{idVendor}=="2e8a", MODE="0666"
EOF

sudo udevadm control --reload-rules
sudo udevadm trigger
```

Unplug/replug the probe.

---

### 3) OpenOCD can’t find scripts (`interface/*.cfg`, `target/*.cfg`)
Your scripts typically live in one of these locations:

- `/usr/local/share/openocd/scripts`
- `/usr/share/openocd/scripts`

Verify:

```bash
ls /usr/local/share/openocd/scripts/interface | head
```

If neither path exists, OpenOCD wasn’t installed correctly.

---

### 4) `picotool` not found
Verify:

```bash
which picotool
picotool version
```

If missing, reinstall from:

```bash
cd ~/pico/picotool/build
sudo cmake --install .
```

---

### 5) “Permission denied” running scripts in `~/pico/tools`
Fix permissions:

```bash
chmod +x ~/pico/tools/*.sh
```

---

### 6) BOOTSEL vs SWD
This workflow is **SWD-first**. If you keep falling back to BOOTSEL, verify:

- OpenOCD detects the probe
- `pico-openocd.sh` starts the GDB server on `:3333`
- Your firmware CMake has a `flash` target pointing to `~/pico/tools/flash.sh`
