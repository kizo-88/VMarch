#!/usr/bin/env bash
U=1001
SIG=$(ls /run/user/$U/hypr | head -1)
RUN="sudo -u arch env XDG_RUNTIME_DIR=/run/user/$U WAYLAND_DISPLAY=wayland-1 HYPRLAND_INSTANCE_SIGNATURE=$SIG"

pkill -x waybar; pkill -f nwg-dock; sleep 1
$RUN hyprctl reload
$RUN hyprctl dispatch exec waybar
$RUN hyprctl dispatch exec -- "nwg-dock-hyprland -r -i 42 -mb 8 -x -c nwg-drawer"
sleep 4
echo "--- running? ---"
pgrep -a waybar | head -2
pgrep -a nwg-dock | head -2
echo RICE2_APPLIED
