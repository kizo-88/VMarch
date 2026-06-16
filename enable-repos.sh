#!/usr/bin/env bash
# Enable multilib + BlackArch repository.
status() { echo "$1" > /root/repos.STATUS; }
status RUNNING
set -x

# 1. multilib (some sec tools need 32-bit libs)
if ! grep -q '^\[multilib\]' /etc/pacman.conf; then
    printf '\n[multilib]\nInclude = /etc/pacman.d/mirrorlist\n' >> /etc/pacman.conf
fi

# 2. BlackArch via official strap.sh
cd /root
curl -fsSL https://blackarch.org/strap.sh -o strap.sh
echo "strap sha:"; sha1sum strap.sh
chmod +x strap.sh
./strap.sh

# 3. sync
pacman -Syu --noconfirm

grep -q '^\[blackarch\]' /etc/pacman.conf && grep -q '^\[multilib\]' /etc/pacman.conf && status DONE || status FAIL
echo "blackarch pkg count:"; pacman -Sl blackarch 2>/dev/null | wc -l
