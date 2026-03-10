# Pico Toolchain Doctor - Windows (PowerShell)

function ok($msg)   { Write-Host "OK  $msg" -ForegroundColor Green }
function warn($msg) { Write-Host "WARN $msg" -ForegroundColor Yellow }
function fail($msg) { Write-Host "FAIL $msg" -ForegroundColor Red; exit 1 }

function Check-Cmd($cmd) {
    $found = Get-Command $cmd -ErrorAction SilentlyContinue
    if ($found) {
        ok "$cmd found: $($found.Source)"
    } else {
        fail "$cmd not found"
    }
}

Write-Host "== Pico Toolchain Doctor =="

Check-Cmd git
Check-Cmd cmake
Check-Cmd ninja
Check-Cmd arm-none-eabi-gcc
Check-Cmd gdb-multiarch
Check-Cmd openocd
Check-Cmd picotool

Write-Host ""
Write-Host "== Env Vars =="
if ($env:PICO_SDK_PATH) {
    ok "PICO_SDK_PATH=$env:PICO_SDK_PATH"
    if (Test-Path $env:PICO_SDK_PATH) {
        ok "PICO_SDK_PATH exists"
    } else {
        warn "PICO_SDK_PATH directory missing"
    }
} else {
    warn "PICO_SDK_PATH not set"
}

Write-Host ""
Write-Host "== OpenOCD scripts =="
$ocdPaths = @(
    "$env:USERPROFILE\.pico-sdk\openocd",
    "C:\Program Files\OpenOCD\scripts",
    "C:\Program Files (x86)\OpenOCD\scripts"
)
$foundOcd = $false
foreach ($p in $ocdPaths) {
    if (Test-Path $p) {
        ok "$p exists"
        $foundOcd = $true
        break
    }
}
if (-not $foundOcd) {
    warn "OpenOCD scripts not found in standard locations"
}

Write-Host ""
Write-Host "== pico-tools =="
$toolsDir = "$env:USERPROFILE\pico\tools"
if (Test-Path $toolsDir) {
    ok "$toolsDir exists"
    if (Test-Path "$toolsDir\flash.ps1")        { ok "flash.ps1 found" }        else { warn "flash.ps1 missing" }
    if (Test-Path "$toolsDir\pico-openocd.ps1") { ok "pico-openocd.ps1 found" } else { warn "pico-openocd.ps1 missing" }
} else {
    warn "$toolsDir missing"
}

Write-Host ""
Write-Host "== USB probes =="
try {
    $probes = Get-PnpDevice -ErrorAction Stop |
        Where-Object { $_.FriendlyName -match "CMSIS|DAP|Pico|RP2040|RP2350|2E8A|0D28" }
    if ($probes) {
        ok "Found possible probe/device: $($probes[0].FriendlyName)"
    } else {
        warn "No obvious probe/device found via Get-PnpDevice"
    }
} catch {
    warn "Could not query USB devices: $_"
}

Write-Host ""
ok "Doctor completed."
