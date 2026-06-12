#!/usr/bin/env bash
SIG=$(ls /run/user/1001/hypr | head -1)
sudo -u arch env XDG_RUNTIME_DIR=/run/user/1001 HYPRLAND_INSTANCE_SIGNATURE=$SIG hyprctl dispatch exec nwg-drawer
echo DRAWER_OPENED
