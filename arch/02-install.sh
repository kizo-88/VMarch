#!/usr/bin/env bash
# Steps 6-7 - mount, reuse the Windows ESP, pacstrap the base system.
# [Arch live USB only]  Run 01-partition.sh first.
set -euo pipefail

DISK=/dev/nvme0n1
ESP=${DISK}p2

red() { printf '\033[31m%s\033[0m\n' "$*"; }
grn() { printf '\033[32m%s\033[0m\n' "$*"; }
ylw() { printf '\033[33m%s\033[0m\n' "$*"; }

[[ $EUID -eq 0 ]] || { red "Run as root."; exit 1; }

ROOT=$(cat /tmp/arch-root-part 2>/dev/null || true)
[[ -n ${ROOT:-} && -b ${ROOT:-} ]] || { red "No root partition recorded. Run ./01-partition.sh first."; exit 1; }

case "$ROOT" in
  ${DISK}p1|${DISK}p2|${DISK}p3|${DISK}p4|${DISK}p5)
    red "REFUSING: recorded root $ROOT is a Windows partition."; exit 1;;
esac
[[ $(blkid -o value -s TYPE "$ROOT") == ext4 ]] || { red "$ROOT is not ext4. Run 01-partition.sh."; exit 1; }

ping -c2 -W3 archlinux.org >/dev/null 2>&1 || {
  red "No network. Connect first:"
  echo "  iwctl"
  echo "    station wlan0 connect <SSID>"
  echo "    exit"
  exit 1
}
grn "Network OK."

# --- Step 6: mount ------------------------------------------------------------
mountpoint -q /mnt && umount -R /mnt
mount "$ROOT" /mnt
mkdir -p /mnt/boot/efi
mount "$ESP" /mnt/boot/efi

# The ESP is shared with Windows. Prove it before we install a bootloader into it.
[[ -f /mnt/boot/efi/EFI/Microsoft/Boot/bootmgfw.efi ]] || {
  red "Windows boot loader not found on the mounted ESP. STOP - wrong partition."; exit 1; }
grn "ESP mounted at /mnt/boot/efi, Windows boot loader intact."

df -h /mnt /mnt/boot/efi

ESP_FREE_M=$(df -Pm /mnt/boot/efi | awk 'NR==2{print $4}')
ylw "ESP free space: ${ESP_FREE_M} MB (GRUB stub needs ~10 MB - this is why we do NOT use systemd-boot)"
(( ESP_FREE_M > 20 )) || red "WARNING: very little room on the ESP."

# --- Step 7: base system ------------------------------------------------------
ylw "Ranking mirrors..."
pacman -Sy --noconfirm reflector >/dev/null 2>&1 || true
reflector --latest 20 --sort rate --protocol https --save /etc/pacman.d/mirrorlist 2>/dev/null || \
  ylw "reflector unavailable, using default mirrorlist"

ylw "pacstrap - this is the long one."
pacstrap -K /mnt \
  base linux linux-firmware intel-ucode \
  grub efibootmgr os-prober \
  networkmanager nano sudo git

genfstab -U /mnt >> /mnt/etc/fstab
grn "fstab written:"
grep -v '^#' /mnt/etc/fstab | grep -v '^$'

# Carry the chroot script inside.
install -Dm755 "$(dirname "$0")/03-chroot.sh" /mnt/root/03-chroot.sh
cp -f "$(dirname "$0")/04-nvidia.sh" /mnt/root/04-nvidia.sh 2>/dev/null || true
chmod +x /mnt/root/04-nvidia.sh 2>/dev/null || true

grn "Base system installed."
cat <<'EOF'

Next:
    arch-chroot /mnt
    /root/03-chroot.sh

EOF
