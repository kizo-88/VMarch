#!/usr/bin/env bash
U=1001
SIG=$(ls /run/user/$U/hypr 2>/dev/null | head -1)
RUN="sudo -u arch env XDG_RUNTIME_DIR=/run/user/$U WAYLAND_DISPLAY=wayland-1 HYPRLAND_INSTANCE_SIGNATURE=$SIG"

echo "--- pywal from new wallpaper ---"
$RUN wal -i /home/arch/Pictures/wall.png -n 2>&1 | tail -1
test -f /home/arch/.cache/wal/colors-kitty.conf && echo KITTY_COLORS_OK

echo "--- set wallpaper ---"
$RUN swww img /home/arch/Pictures/wall.png --transition-type grow --transition-duration 1

echo "--- reload hyprland config ---"
$RUN hyprctl reload

echo "--- close chrome/brave/old kitty windows ---"
pkill -f google-chrome 2>/dev/null
pkill -f brave 2>/dev/null
pkill -x kitty 2>/dev/null
sleep 1

echo "--- open riced kitty (zsh will run fastfetch) ---"
$RUN hyprctl dispatch exec kitty
echo RICE_APPLIED
