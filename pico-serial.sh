#!/usr/bin/env bash

PORT=${1:-/dev/ttyACM0}
BAUD=${2:-115200}

echo "📟 Pico serial monitor on $PORT @ $BAUD"
echo "Ctrl+A X para salir (picocom)"

picocom "$PORT" -b "$BAUD" --omap crlf
