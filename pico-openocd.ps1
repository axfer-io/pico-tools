# Lanza OpenOCD como servidor GDB para debug con Pico - Windows (PowerShell)
# Usage: .\pico-openocd.ps1 [path\to\app.elf]

$PICO_SWD = if ($env:PICO_SWD) { $env:PICO_SWD } else { "DEBUGPROBE" }
$PROJ_DIR  = if ($env:PROJ_DIR) { $env:PROJ_DIR } else { (Get-Location).Path }

# -------- Resolver ELF --------
if ($args.Count -ge 1) {
    $ELF = (Resolve-Path $args[0]).Path
} else {
    $buildDir = Join-Path $PROJ_DIR "build"
    $elfs = @(Get-ChildItem -Path $buildDir -Recurse -Filter "*.elf" -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending)
    if ($elfs.Count -eq 0) {
        Write-Host "FAIL No encontre ningun .elf en: $buildDir\**" -ForegroundColor Red
        Write-Host "     Compila primero o pasa la ruta como argumento:"
        Write-Host "     $($MyInvocation.MyCommand) \ruta\a\tu.elf"
        exit 1
    }
    $ELF = $elfs[0].FullName
}

Write-Host "PICO_SWD=$PICO_SWD"
Write-Host "ELF=$ELF"

# -------- Interfaz SWD --------
$interface = "cmsis-dap.cfg"
$speed     = "1000"

switch ($PICO_SWD) {
    "RPI"        { $interface = "raspberrypi-native.cfg" }
    "PICOPROBE"  { $interface = "picoprobe.cfg" }
    "DEBUGPROBE" { $interface = "cmsis-dap.cfg" }
    default {
        Write-Host "FAIL PICO_SWD invalido: $PICO_SWD (usa RPI|PICOPROBE|DEBUGPROBE)" -ForegroundColor Red
        exit 1
    }
}

# -------- Detectar target (rp2040 vs rp2350) --------
$target   = "rp2350.cfg"
$detected = "unknown"

if (Get-Command picotool -ErrorAction SilentlyContinue) {
    $info = & picotool info $ELF 2>$null
    if      ($info -match "RP2040") { $target = "rp2040.cfg"; $detected = "RP2040" }
    elseif  ($info -match "RP2350") { $target = "rp2350.cfg"; $detected = "RP2350" }
}

if ($detected -eq "unknown") {
    $strCmd = Get-Command arm-none-eabi-strings -ErrorAction SilentlyContinue
    if ($strCmd) {
        $content = & arm-none-eabi-strings $ELF 2>$null
        if      ($content -match "(?i)rp2040") { $target = "rp2040.cfg"; $detected = "RP2040(strings)" }
        elseif  ($content -match "(?i)rp2350") { $target = "rp2350.cfg"; $detected = "RP2350(strings)" }
    }
}

if ($detected -eq "unknown") {
    Write-Host "WARN No pude detectar RP2040/RP2350 desde el ELF. Usando default: $target" -ForegroundColor Yellow
} else {
    Write-Host "OK  Detected: $detected -> target/$target" -ForegroundColor Green
}

Write-Host "Interface=$interface"
Write-Host "Target=$target"
Write-Host "Speed=${speed}kHz"

# -------- Localizar OpenOCD + scripts TCL --------
$OPENOCD_BIN     = ""
$OPENOCD_SCRIPTS = ""

$picoSdkOcd = "$env:USERPROFILE\.pico-sdk\openocd"
if (Test-Path $picoSdkOcd) {
    $latestDir = Get-ChildItem $picoSdkOcd -Directory -ErrorAction SilentlyContinue |
        Sort-Object Name -Descending | Select-Object -First 1
    if ($latestDir) {
        $ocdExe = Join-Path $latestDir.FullName "openocd.exe"
        if (Test-Path $ocdExe) {
            $OPENOCD_BIN = $ocdExe
            $scriptsDir  = Join-Path $latestDir.FullName "scripts"
            if (Test-Path $scriptsDir) { $OPENOCD_SCRIPTS = $scriptsDir }
        }
    }
}

if (-not $OPENOCD_BIN) {
    $ocdCmd = Get-Command openocd -ErrorAction SilentlyContinue
    if ($ocdCmd) { $OPENOCD_BIN = $ocdCmd.Source }
}

if (-not $OPENOCD_SCRIPTS) {
    $candidates = @(
        "C:\Program Files\OpenOCD\scripts",
        "C:\Program Files (x86)\OpenOCD\scripts"
    )
    if ($env:PICO_SDK_PATH) {
        $candidates += (Join-Path $env:PICO_SDK_PATH "..\openocd\scripts")
    }
    $candidates += "$env:USERPROFILE\pico\openocd\scripts"

    foreach ($p in $candidates) {
        if (Test-Path $p) { $OPENOCD_SCRIPTS = (Resolve-Path $p).Path; break }
    }
}

if (-not $OPENOCD_BIN) {
    Write-Host "FAIL openocd no encontrado." -ForegroundColor Red
    exit 1
}
if (-not $OPENOCD_SCRIPTS) {
    Write-Host "FAIL No encontre scripts de OpenOCD en las rutas estandar." -ForegroundColor Red
    exit 1
}

# -------- OpenOCD (GDB server) --------
& $OPENOCD_BIN `
    -s $OPENOCD_SCRIPTS `
    -f "interface/$interface" `
    -f "target/$target" `
    -c "transport select swd" `
    -c "adapter speed $speed" `
    -c "gdb_port 3333" `
    -c "tcl_port 6666" `
    -c "telnet_port 4444"
