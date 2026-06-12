#!/usr/bin/env bash
U=$(id -u arch)
SIG=$(ls /run/user/$U/hypr 2>/dev/null | head -1)
echo "--- generate colorful wallpaper (plasma fractal) ---"
magick -size 1920x1080 -seed 42 plasma:fractal -blur 0x4 /home/arch/Pictures/wall.png
chown arch:arch /home/arch/Pictures/wall.png
echo "--- pywal palette ---"
sudo -u arch env XDG_RUNTIME_DIR=/run/user/$U wal -i /home/arch/Pictures/wall.png -n 2>&1 | tail -2
test -f /home/arch/.cache/wal/colors && echo PYWAL_OK || echo PYWAL_FAIL
echo "--- apply wallpaper via swww ---"
sudo -u arch env XDG_RUNTIME_DIR=/run/user/$U HYPRLAND_INSTANCE_SIGNATURE=$SIG swww img /home/arch/Pictures/wall.png --transition-type grow
echo SWWW_APPLIED
