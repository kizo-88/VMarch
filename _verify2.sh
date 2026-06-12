#!/usr/bin/env bash
echo "--- session processes ---"
pgrep -a Hyprland | head -2
pgrep -a swww-daemon | head -2
pgrep -a waybar | head -2
echo "--- pywal cache ---"
ls /home/arch/.cache/wal/ 2>/dev/null | head -5
echo "--- launch kitty + brave inside the session ---"
U=$(id -u arch)
export XDG_RUNTIME_DIR=/run/user/$U
SIG=$(ls /run/user/$U/hypr 2>/dev/null | head -1)
export HYPRLAND_INSTANCE_SIGNATURE=$SIG
echo "sig=$SIG"
sudo -u arch env XDG_RUNTIME_DIR=$XDG_RUNTIME_DIR HYPRLAND_INSTANCE_SIGNATURE=$SIG hyprctl dispatch exec kitty
sleep 1
sudo -u arch env XDG_RUNTIME_DIR=$XDG_RUNTIME_DIR HYPRLAND_INSTANCE_SIGNATURE=$SIG hyprctl dispatch exec "brave --no-sandbox --ozone-platform=wayland"
echo LAUNCHED_OK
