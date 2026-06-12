#!/usr/bin/env bash
echo "===== find hyprland logs ====="
ls -la /root/.cache/hyprland/ 2>/dev/null
find /run/user/0 /tmp /root/.local/share/hyprland /root/.cache -iname '*hypr*log*' 2>/dev/null
echo "===== hyprland log content (last 40) ====="
for f in /root/.cache/hyprland/hyprland.log /run/user/0/hypr/*/hyprland.log $(find /run/user/0/hypr -name 'hyprland.log' 2>/dev/null); do
  [ -f "$f" ] && { echo "--- $f ---"; tail -n 40 "$f"; }
done
echo "===== xsession-errors ====="
tail -n 30 /root/.xsession-errors 2>/dev/null
echo "===== dri devices ====="
ls -la /dev/dri/ 2>/dev/null
echo "===== loaded video modules ====="
lsmod | grep -E 'vmwgfx|vboxvideo|drm' 2>/dev/null
echo "===== glinfo ====="
glxinfo -B 2>/dev/null | head -8 || echo "no glxinfo"
