#!/usr/bin/env bash
# Guarded Arch install for the Dell Precision 3640 (single 953.9 GB NVMe, dual boot).
# Run as root INSIDE the Arch installer, AFTER creating the new root partition in cfdisk.
# It refuses to touch anything except the partition you name.
set -euo pipefail

DISK=/dev/nvme0n1
ESP=${DISK}p1          # existing 150 MB Windows ESP - MOUNTED, NEVER FORMATTED
ROOT=${1:-${DISK}p6}   # the partition YOU created; override: ./01-install.sh /dev/nvme0n1p7

red(){ printf '\033[1;31m%s\033[0m\n' "$*"; }
grn(){ printf '\033[1;32m%s\033[0m\n' "$*"; }
ylw(){ printf '\033[1;33m%s\033[0m\n' "$*"; }
die(){ red "ABORT: $*"; exit 1; }

echo "== Preflight =="

[[ $EUID -eq 0 ]] || die "must run as root"
[[ -d /sys/firmware/efi/efivars ]] || die "not booted in UEFI mode - reboot and pick the UEFI entry for the USB"
[[ -b $DISK ]] || die "$DISK not found - the NVMe is still hidden behind Intel RST (see Phase 5)"
[[ -b $ROOT ]] || die "$ROOT does not exist - create it in cfdisk first"
[[ -b $ESP  ]] || die "$ESP (EFI System Partition) not found - wrong disk?"

# --- prove we are on the machine we think we are, before destroying anything ---
esp_fs=$(blkid -o value -s TYPE "$ESP" || true)
[[ $esp_fs == vfat ]] || die "$ESP is '$esp_fs', expected vfat - this is not the Windows ESP"

mkdir -p /tmp/espchk
mount -o ro "$ESP" /tmp/espchk
if [[ ! -d /tmp/espchk/EFI/Microsoft ]]; then
  umount /tmp/espchk; die "no EFI/Microsoft on $ESP - wrong disk, refusing to continue"
fi
umount /tmp/espchk
grn "  ok: $ESP is the Windows ESP (EFI/Microsoft present)"

win_fs=$(blkid -o value -s TYPE ${DISK}p3 || true)
[[ $win_fs == ntfs ]] || die "${DISK}p3 is '$win_fs', expected ntfs (Windows) - layout does not match"
grn "  ok: ${DISK}p3 is the Windows NTFS volume - will not be touched"

# --- the target must be the new, empty partition, not something in use ---
case "$ROOT" in
  ${DISK}p1|${DISK}p2|${DISK}p3|${DISK}p4|${DISK}p5)
    die "$ROOT is an existing Windows partition. Refusing." ;;
esac
if mount | grep -q "^$ROOT "; then die "$ROOT is currently mounted"; fi

sz=$(blockdev --getsize64 "$ROOT")
szg=$(( sz / 1024 / 1024 / 1024 ))
(( szg >= 40 ))  || die "$ROOT is only ${szg} GB - too small, did you pick the right partition?"
(( szg <= 400 )) || die "$ROOT is ${szg} GB - larger than expected, refusing in case it is the Windows volume"
grn "  ok: target $ROOT is ${szg} GB"

existing=$(blkid -o value -s TYPE "$ROOT" || true)
[[ -n $existing ]] && ylw "  WARNING: $ROOT already contains a '$existing' filesystem - it will be erased"

echo
lsblk -o NAME,SIZE,FSTYPE,LABEL,MOUNTPOINT "$DISK"
echo
red "About to ERASE $ROOT (${szg} GB) and install Arch onto it."
echo "Windows partitions p1..p5 will NOT be modified."
read -rp "Type ERASE to proceed: " confirm
[[ $confirm == ERASE ]] || die "not confirmed"

echo; echo "== Formatting and mounting =="
mkfs.ext4 -L archroot "$ROOT"
mount "$ROOT" /mnt
mkdir -p /mnt/boot/efi
mount "$ESP" /mnt/boot/efi          # mount only - never mkfs
grn "  mounted $ROOT -> /mnt, $ESP -> /mnt/boot/efi"

echo; echo "== Swapfile (8 GB) =="
mkswap -U clear -s 8G -F /mnt/swapfile
swapon /mnt/swapfile

echo; echo "== Base system =="
pacman -Sy --noconfirm archlinux-keyring
pacstrap -K /mnt base linux linux-firmware intel-ucode \
  base-devel nano vim networkmanager grub efibootmgr os-prober \
  sudo git man-db ntfs-3g

genfstab -U /mnt >> /mnt/etc/fstab
grep -q swapfile /mnt/etc/fstab || echo "/swapfile none swap defaults 0 0" >> /mnt/etc/fstab

install -m755 "$(dirname "$0")/02-configure.sh" /mnt/root/02-configure.sh 2>/dev/null || true

echo
grn "Base install done."
echo "Next:  arch-chroot /mnt"
echo "then:  /root/02-configure.sh"
