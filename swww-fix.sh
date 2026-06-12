#!/usr/bin/env bash
# Replace the 'awww' fork with the genuine 'swww' package the user asked for.
status() { echo "$1" > /root/swww-fix.STATUS; }
status RUNNING

echo "== removing awww fork =="
pacman -Rns --noconfirm awww 2>/dev/null || pacman -Rdd --noconfirm awww 2>/dev/null || true

echo "== temp sudo for builder =="
echo 'builder ALL=(ALL) NOPASSWD: ALL' > /etc/sudoers.d/99-builder
chmod 440 /etc/sudoers.d/99-builder

echo "== build + install genuine swww from AUR =="
sudo -u builder bash -c '
  set -e
  cd /home/builder
  rm -rf swww
  git clone --depth=1 https://aur.archlinux.org/swww.git
  cd swww
  makepkg -si --noconfirm
'
RC=$?

echo "== remove temp sudo =="
rm -f /etc/sudoers.d/99-builder

if command -v swww >/dev/null 2>&1 && command -v swww-daemon >/dev/null 2>&1; then
  echo "swww OK: $(swww --version 2>/dev/null | head -1)"
  status DONE
else
  echo "swww still missing (rc=$RC)"
  status FAIL
fi
