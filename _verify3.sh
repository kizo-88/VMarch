#!/usr/bin/env bash
U=$(id -u arch)
SIG=$(ls /run/user/$U/hypr 2>/dev/null | head -1)
echo "--- pywal output ---"
ls -la /home/arch/.cache/wal/ 2>/dev/null | head -10
echo "--- regenerate palette as arch (in case first run raced the wallpaper) ---"
sudo -u arch env XDG_RUNTIME_DIR=/run/user/$U wal -i /home/arch/Pictures/wall.png -n 2>&1 | tail -3
ls /home/arch/.cache/wal/colors 2>/dev/null && echo PYWAL_OK
echo "--- close brave test window, launch chrome ---"
sudo -u arch env XDG_RUNTIME_DIR=/run/user/$U HYPRLAND_INSTANCE_SIGNATURE=$SIG hyprctl dispatch killactive
sleep 1
sudo -u arch env XDG_RUNTIME_DIR=/run/user/$U HYPRLAND_INSTANCE_SIGNATURE=$SIG hyprctl dispatch exec "google-chrome-stable --ozone-platform=wayland"
echo CHROME_LAUNCHED
