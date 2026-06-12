#!/usr/bin/env bash
export XDG_RUNTIME_DIR=/run/user/0
export WLR_RENDERER_ALLOW_SOFTWARE=1
export LIBGL_ALWAYS_SOFTWARE=1
export WLR_NO_HARDWARE_CURSORS=1
export AQ_TRACE=1
mkdir -p /run/user/0 && chmod 700 /run/user/0
rm -f /root/hypr-run.log
echo "launching Hyprland (12s)..."
timeout 12 Hyprland > /root/hypr-run.log 2>&1
echo "exit=$?"
echo "===== hypr-run.log ====="
cat /root/hypr-run.log
