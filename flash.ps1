# Flash Pico firmware via OpenOCD+SWD - Windows (PowerShell)
# Usage: .\flash.ps1 [path\to\app.elf]

# -------- Config SWD --------
if (-not $env:PICO_SWD) { $env:PICO_SWD = "DEBUGPROBE" }
$PICO_SWD = $env:PICO_SWD

# -------- Resolver ELF --------
$elf = if ($args.Count -ge 1) { $args[0] } else { $null }

if (-not $elf) {
    $candidates = @()
    if (Test-Path "build") {
        $candidates = @(Get-ChildItem -Path "build" -Recurse -Depth 2 -Filter "*.elf" -ErrorAction SilentlyContinue |
            Sort-Object LastWriteTime -Descending)
    }
    if ($candidates.Count -eq 0) {
        $candidates = @(Get-ChildItem -Path "." -Filter "*.elf" -ErrorAction SilentlyContinue |
            Sort-Object LastWriteTime -Descending)
    }
    if ($candidates.Count -eq 0) {
        Write-Host "FAIL No se encontro ningun .elf (pasalo como argumento: .\flash.ps1 path\to\app.elf)" -ForegroundColor Red
        exit 1
    }
    $elf = $candidates[0].FullName
}

$elf = (Resolve-Path $elf).Path

# -------- Elegir interfaz y velocidad --------
$interface = "cmsis-dap.cfg"
$speed     = "5000"

switch ($PICO_SWD) {
    "RPI" {
        $interface = "raspberrypi-native.cfg"
        $speed     = "1000"
    }
    "PICOPROBE" {
        $interface = "picoprobe.cfg"
    }
    default {
        $interface = "cmsis-dap.cfg"
    }
}

# -------- Detectar target rp2040 vs rp2350 --------
$target = "rp2040.cfg"

if (Get-Command picotool -ErrorAction SilentlyContinue) {
    $info = & picotool info $elf 2>$null
    if ($info -match "RP2350") { $target = "rp2350.cfg" }
}

if ($target -eq "rp2040.cfg") {
    # Fallback: arm-none-eabi-strings (parte del toolchain ARM en Windows)
    $strCmd = Get-Command arm-none-eabi-strings -ErrorAction SilentlyContinue
    if ($strCmd) {
        $content = & arm-none-eabi-strings $elf 2>$null
        if ($content -match "(?i)rp2350") { $target = "rp2350.cfg" }
    }
}

# -------- Localizar OpenOCD --------
$OPENOCD_BIN = ""
$OPENOCD_TCL = ""

$picoSdkOcd = "$env:USERPROFILE\.pico-sdk\openocd"
if (Test-Path $picoSdkOcd) {
    $latestDir = Get-ChildItem $picoSdkOcd -Directory -ErrorAction SilentlyContinue |
        Sort-Object Name -Descending | Select-Object -First 1
    if ($latestDir) {
        $ocdExe = Join-Path $latestDir.FullName "openocd.exe"
        if (Test-Path $ocdExe) {
            $OPENOCD_BIN = $ocdExe
            $scriptsDir  = Join-Path $latestDir.FullName "scripts"
            $tclDir      = Join-Path $latestDir.FullName "tcl"
            if      (Test-Path $scriptsDir) { $OPENOCD_TCL = $scriptsDir }
            elseif  (Test-Path $tclDir)     { $OPENOCD_TCL = $tclDir }
        }
    }
}

if (-not $OPENOCD_BIN) {
    $ocdCmd = Get-Command openocd -ErrorAction SilentlyContinue
    if ($ocdCmd) { $OPENOCD_BIN = $ocdCmd.Source }
}

if (-not $OPENOCD_TCL) {
    if ($env:PICO_SDK_PATH) {
        $sdkTcl = Join-Path $env:PICO_SDK_PATH "..\openocd\tcl"
        if (Test-Path $sdkTcl) { $OPENOCD_TCL = (Resolve-Path $sdkTcl).Path }
    }
}
if (-not $OPENOCD_TCL) {
    $picoTcl = "$env:USERPROFILE\pico\openocd\tcl"
    if (Test-Path $picoTcl) { $OPENOCD_TCL = $picoTcl }
}

if (-not $OPENOCD_BIN) {
    Write-Host "FAIL openocd no encontrado. Instalalo o usa el del pico-sdk." -ForegroundColor Red
    exit 1
}
if (-not $OPENOCD_TCL) {
    Write-Host "FAIL No se encontro la carpeta de scripts TCL de OpenOCD." -ForegroundColor Red
    Write-Host "     Prueba configurando PICO_SDK_PATH o instala el paquete OpenOCD del SDK."
    exit 1
}

Write-Host "ELF:       $elf"
Write-Host "Interface: $interface"
Write-Host "Target:    $target"
Write-Host "Speed:     $speed kHz"
Write-Host "OpenOCD:   $OPENOCD_BIN"
Write-Host "TCL path:  $OPENOCD_TCL"

# -------- Programar --------
& $OPENOCD_BIN -s $OPENOCD_TCL `
    -f "interface/$interface" `
    -f "target/$target" `
    -c "adapter speed $speed" `
    -c "program `"$elf`" verify reset exit"

if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host "OK  Deployed" -ForegroundColor Green
$armSize = Get-Command arm-none-eabi-size -ErrorAction SilentlyContinue
if ($armSize) { & arm-none-eabi-size $elf }
