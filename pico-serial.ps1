# Monitor serial USB para Pico - Windows (PowerShell)
# Usage: .\pico-serial.ps1 [COM3] [115200]
#
# En Windows el puerto serie es COMx (ej: COM3, COM4).
# Puedes ver el puerto en el Administrador de dispositivos
# o con: Get-PnpDevice | Where-Object { $_.FriendlyName -match "COM" }

$PORT = if ($args.Count -ge 1) { $args[0] } else { "COM3" }
$BAUD = if ($args.Count -ge 2) { [int]$args[1] } else { 115200 }

Write-Host "Pico serial monitor on $PORT @ $BAUD"

# 1) tio (multiplataforma, disponible via scoop/winget/choco)
if (Get-Command tio -ErrorAction SilentlyContinue) {
    & tio $PORT -b $BAUD
    exit $LASTEXITCODE
}

# 2) PuTTY
if (Get-Command putty -ErrorAction SilentlyContinue) {
    Write-Host "Usando PuTTY. Cierra la ventana para salir."
    & putty -serial $PORT -sercfg "$BAUD,8,n,1,N"
    exit $LASTEXITCODE
}

# 3) Monitor serie nativo con System.IO.Ports.SerialPort
Write-Host "Abriendo monitor serial con PowerShell (Ctrl+C para salir)..." -ForegroundColor Cyan
try {
    $port = New-Object System.IO.Ports.SerialPort $PORT, $BAUD, "None", 8, "One"
    $port.ReadTimeout  = 100
    $port.WriteTimeout = 500
    $port.Open()
    Write-Host "Conectado a $PORT @ $BAUD. Ctrl+C para salir." -ForegroundColor Green

    # Habilitar entrada de teclado hacia el puerto
    [console]::TreatControlCAsInput = $false
    try {
        while ($true) {
            # Leer datos del Pico
            try {
                $data = $port.ReadExisting()
                if ($data) { Write-Host $data -NoNewline }
            } catch [System.TimeoutException] {}

            # Enviar teclas al Pico
            if ([console]::KeyAvailable) {
                $key = [console]::ReadKey($true)
                $port.Write($key.KeyChar.ToString())
            }

            Start-Sleep -Milliseconds 10
        }
    } finally {
        $port.Close()
    }
} catch {
    Write-Host "FAIL Error abriendo $PORT`: $_" -ForegroundColor Red
    Write-Host "  - Verifica que el Pico este conectado y el puerto sea correcto."
    Write-Host "  - Instala tio (scoop install tio) o PuTTY para mejor experiencia."
    Write-Host "  - Puertos disponibles: $([System.IO.Ports.SerialPort]::GetPortNames() -join ', ')"
    exit 1
}
