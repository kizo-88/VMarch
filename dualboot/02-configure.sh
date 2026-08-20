#!/usr/bin/env bash
# Run INSIDE arch-chroot /mnt  (second half of the install).
# Configures locale/time/user, installs GRUB, and makes it find Windows.
set -euo pipefail
# These are deliberately ARCH_-prefixed. bash sets HOSTNAME itself, so a plain
# ${HOSTNAME:-precision} silently resolves to the live USB name ("archiso") and the
# default never applies. USERNAME/TZ can be set by the environment for the same reason.

ARCH_TZ=${ARCH_TZ:-Europe/London}
ARCH_LOCALE=${ARCH_LOCALE:-en_GB.UTF-8}
ARCH_HOSTNAME=${ARCH_HOSTNAME:-precision}
ARCH_USER=${ARCH_USER:-kizo}

grn(){ printf '\033[1;32m%s\033[0m\n' "$*"; }
red(){ printf '\033[1;31m%s\033[0m\n' "$*"; }
ylw(){ printf '\033[1;33m%s\033[0m\n' "$*"; }

echo "== Time and locale =="
ln -sf "/usr/share/zoneinfo/$ARCH_TZ" /etc/localtime
hwclock --systohc
sed -i "s/^#\(${ARCH_LOCALE//./\.}\)/\1/" /etc/locale.gen
locale-gen
echo "LANG=$ARCH_LOCALE" > /etc/locale.conf

echo "== Host and network =="
echo "$ARCH_HOSTNAME" > /etc/hostname
cat > /etc/hosts <<HOSTS
127.0.0.1   localhost
::1         localhost
127.0.1.1   $ARCH_HOSTNAME.localdomain $ARCH_HOSTNAME
HOSTS
systemctl enable NetworkManager

echo "== Bootloader =="
[[ -d /boot/efi/EFI ]] || { red "ESP not mounted at /boot/efi - re-mount it before running this"; exit 1; }

grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=Arch

# Arch ships os-prober disabled; without this there is no Windows entry.
if grep -q '^GRUB_DISABLE_OS_PROBER' /etc/default/grub; then
  sed -i 's/^GRUB_DISABLE_OS_PROBER.*/GRUB_DISABLE_OS_PROBER=false/' /etc/default/grub
else
  echo 'GRUB_DISABLE_OS_PROBER=false' >> /etc/default/grub
fi

grub-mkconfig -o /boot/grub/grub.cfg 2>&1 | tee /tmp/grub.log

if grep -qi 'windows' /tmp/grub.log || grep -qi 'windows' /boot/grub/grub.cfg; then
  grn "  Windows Boot Manager found and added to the GRUB menu."
else
  ylw "  WARNING: no Windows entry detected."
  ylw "  Check:  ls /boot/efi/EFI   (expect Microsoft and Arch)"
  ylw "  Then re-run: grub-mkconfig -o /boot/grub/grub.cfg"
  ylw "  You can always reach Windows via F12 at boot regardless."
fi

echo "== Accounts =="
if ! id "$ARCH_USER" &>/dev/null; then
  useradd -m -G wheel "$ARCH_USER"
fi
# A drop-in is safer than editing /etc/sudoers in place; validate before keeping it.
echo '%wheel ALL=(ALL:ALL) ALL' > /etc/sudoers.d/10-wheel
chmod 0440 /etc/sudoers.d/10-wheel
if ! visudo -c -f /etc/sudoers.d/10-wheel >/dev/null; then
  rm -f /etc/sudoers.d/10-wheel
  red "sudoers drop-in failed validation - grant sudo manually"
fi

echo
echo "Set the root password:"; passwd
echo "Set the password for $ARCH_USER:"; passwd "$ARCH_USER"

echo
grn "Configuration done."
echo "Then:  exit ; umount -R /mnt ; reboot   (pull the USB as it restarts)"
echo
echo "After first boot into Arch, for the RTX 3080:"
echo "  sudo pacman -S nvidia nvidia-utils nvidia-settings"
