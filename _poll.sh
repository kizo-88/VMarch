#!/usr/bin/env bash
echo "STATUS=$(cat /root/install-all.STATUS 2>/dev/null || echo none)"
echo "ACTIVE=$(systemctl is-active installall 2>/dev/null)"
echo "cache_pkgs=$(ls /var/cache/pacman/pkg 2>/dev/null | wc -l)"
for p in hyprland python-pywal swww brave-bin google-chrome yay; do
  if pacman -Q "$p" >/dev/null 2>&1; then echo "INSTALLED $p $(pacman -Q $p | awk '{print $2}')"; else echo "pending   $p"; fi
done
echo "--- last real journal line ---"
journalctl -u installall --no-pager -o cat 2>/dev/null | grep -vE 'Retrieving|^\($|installing|^warning|skipping' | tail -n 4
