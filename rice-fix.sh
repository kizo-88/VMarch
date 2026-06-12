#!/usr/bin/env bash
U=1001
SIG=$(ls /run/user/$U/hypr 2>/dev/null | head -1)
RUN="sudo -u arch env XDG_RUNTIME_DIR=/run/user/$U WAYLAND_DISPLAY=wayland-1 HYPRLAND_INSTANCE_SIGNATURE=$SIG"

echo "--- drop the bad windowrule line ---"
sed -i '/^windowrule = opacity/d' /home/arch/.config/hypr/hyprland.conf
$RUN hyprctl reload

echo "--- try kitty manually, capture errors ---"
timeout 6 sudo -u arch env XDG_RUNTIME_DIR=/run/user/$U WAYLAND_DISPLAY=wayland-1 kitty > /tmp/kitty.log 2>&1
echo "kitty exit=$?"
tail -n 8 /tmp/kitty.log
echo "--- windows now open ---"
$RUN hyprctl clients | grep -E 'class|title' | head -6
