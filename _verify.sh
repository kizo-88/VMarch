#!/usr/bin/env bash
echo "--- binaries ---"
for b in Hyprland hyprland swww swww-daemon brave google-chrome-stable wal waybar wofi kitty; do
  p=$(command -v "$b" 2>/dev/null)
  echo "$b -> ${p:-MISSING}"
done
echo "--- wayland session entries ---"
ls /usr/share/wayland-sessions/ 2>/dev/null
echo "--- remove temp build sudoers ---"
rm -f /etc/sudoers.d/99-builder && echo "builder NOPASSWD removed"
echo "--- hypr config ---"
ls -la /root/.config/hypr/ 2>/dev/null
echo "--- current graphical target / who is logged in ---"
systemctl is-active display-manager
who 2>/dev/null
