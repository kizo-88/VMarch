#!/usr/bin/env bash
set -x
echo "=== before ==="
lsblk /dev/sda
df -h /

# parted is reliable for online growth of the last partition
pacman -Sy --noconfirm parted >/dev/null 2>&1

# Grow partition 2 to fill the disk (MBR, sda2 is last partition)
parted -s /dev/sda resizepart 2 100%
partprobe /dev/sda 2>/dev/null
sleep 1

# Grow the ext4 filesystem online
resize2fs /dev/sda2

echo "=== after ==="
lsblk /dev/sda
df -h /
echo GROW_DONE
