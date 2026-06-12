#!/usr/bin/env bash
pacman -Sy >/dev/null 2>&1
for p in hyprland swww python-pywal pywal16 flatpak python-pipx git base-devel sudo kitty waybar wofi xdg-desktop-portal-hyprland wl-clipboard mesa; do
  if pacman -Si "$p" >/dev/null 2>&1; then
    echo "REPO    $p"
  else
    echo "NOTREPO $p"
  fi
done
