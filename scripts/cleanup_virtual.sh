#!/bin/bash

PID_FILE="/tmp/app_virtual_display.pid"

if [ -f "$PID_FILE" ]; then
    echo "Stopping virtual display and app..."
    while read pid; do
        kill -9 $pid 2>/dev/null
    done < "$PID_FILE"
    rm "$PID_FILE"
    echo "Done."
else
    echo "No PID file found. Cleanup manually if needed."
    pkill -9 -f cloudtolocalllm
    pkill -9 Xvfb
fi
