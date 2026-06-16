#!/usr/bin/env bash
set -x
pacman -Sy --noconfirm cloud-guest-utils >/dev/null 2>&1

# growpart resizes the (last, mounted) partition online
growpart /dev/sda 2

# kernel: update the in-use partition's size
partx -u /dev/sda 2>/dev/null
resize2fs /dev/sda2

echo "=== after ==="
df -h / | tail -1
lsblk /dev/sda | grep sda2
echo GROW2_DONE
