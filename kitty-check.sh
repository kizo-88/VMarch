#!/usr/bin/env bash
U=1001
SIG=$(ls /run/user/$U/hypr | head -1)
RUN="sudo -u arch env XDG_RUNTIME_DIR=/run/user/$U HYPRLAND_INSTANCE_SIGNATURE=$SIG"
echo "--- clients ---"
$RUN hyprctl clients
echo "--- kitty processes ---"
pgrep -a kitty
echo "--- xwayland running? ---"
pgrep -a Xwayland
echo "--- session env DISPLAY ---"
tr '\0' '\n' < /proc/$(pgrep -x Hyprland | head -1)/environ | grep -E 'DISPLAY|XDG_SESSION'
