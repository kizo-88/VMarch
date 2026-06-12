#!/usr/bin/env bash
for p in nwg-drawer nwg-dock-hyprland thunar papirus-icon-theme; do
  if pacman -Si "$p" >/dev/null 2>&1; then echo "REPO    $p"; else echo "NOTREPO $p"; fi
done
pacman -Q thunar 2>/dev/null && echo THUNAR_ALREADY
ls /usr/share/applications/ | grep -iE 'brave|chrome|foot|thunar' | head -8
