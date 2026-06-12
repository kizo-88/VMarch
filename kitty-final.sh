#!/usr/bin/env bash
grep -q 'linux_display_server' /home/arch/.config/kitty/kitty.conf || \
    printf 'linux_display_server x11\n' >> /home/arch/.config/kitty/kitty.conf
chown arch:arch /home/arch/.config/kitty/kitty.conf
SIG=$(ls /run/user/1001/hypr | head -1)
sudo -u arch env XDG_RUNTIME_DIR=/run/user/1001 HYPRLAND_INSTANCE_SIGNATURE=$SIG hyprctl dispatch exec kitty
echo KITTY_RELAUNCHED
