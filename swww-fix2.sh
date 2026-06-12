#!/usr/bin/env bash
# Retry swww build with swap + single-job compile to avoid OOM.
status() { echo "$1" > /root/swww-fix.STATUS; }
status RUNNING

echo "== ensure 4G swapfile =="
if ! swapon --show | grep -q /swapfile; then
    if [ ! -f /swapfile ]; then
        fallocate -l 4G /swapfile || dd if=/dev/zero of=/swapfile bs=1M count=4096
        chmod 600 /swapfile
        mkswap /swapfile
    fi
    swapon /swapfile
    grep -q '/swapfile' /etc/fstab || echo '/swapfile none swap defaults 0 0' >> /etc/fstab
fi
free -h

echo "== temp sudo for builder =="
echo 'builder ALL=(ALL) NOPASSWD: ALL' > /etc/sudoers.d/99-builder
chmod 440 /etc/sudoers.d/99-builder

echo "== build genuine swww (single job) =="
sudo -u builder bash -c '
  set -e
  export CARGO_BUILD_JOBS=1
  export MAKEFLAGS="-j1"
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
  echo "swww OK"
  status DONE
else
  echo "swww still missing (rc=$RC)"
  status FAIL
fi
