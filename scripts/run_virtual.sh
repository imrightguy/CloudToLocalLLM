#!/bin/bash
# DEPRECATED — moved to archive 2026-06-03
# This script had hardcoded /mnt/data/... paths from a previous dev environment.
# Superseded by scripts/tests/test_run_virtual_*.sh for testing and
# the build-desktop.yml workflow for production runs.
# Do not use — keep for reference only.

# Configuration
DISPLAY_NUM=99
RESOLUTION="1920x1080x24"
APP_PATH="/mnt/data/projects/CloudToLocalLLM/build/linux/x64/debug/bundle/cloudtolocalllm"
LOG_FILE="/tmp/app_virtual_display.log"
PID_FILE="/tmp/app_virtual_display.pid"

# Start Xvfb
echo "Starting Xvfb on display :$DISPLAY_NUM..."
Xvfb :$DISPLAY_NUM -screen 0 $RESOLUTION &
XVFB_PID=$!
sleep 2

# Run the app
echo "Starting app on display :$DISPLAY_NUM..."
export DISPLAY=:$DISPLAY_NUM
$APP_PATH > $LOG_FILE 2>&1 &
APP_PID=$!

# Save PIDs
echo $XVFB_PID > $PID_FILE
echo $APP_PID >> $PID_FILE

echo "App running on virtual display :$DISPLAY_NUM (PID: $APP_PID)"
echo "Xvfb running (PID: $XVFB_PID)"
echo "Use 'DISPLAY=:$DISPLAY_NUM import -window root screenshot.png' to capture."
