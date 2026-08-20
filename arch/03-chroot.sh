#!/usr/bin/env bash
# Step 8 - system config + GRUB + making Windows appear in the menu.
# Runs INSIDE arch-chroot /mnt.
set -euo pipefail

TZ_REGION=${TZ_REGION:-Asia/Kuala_Lumpur}
# NOT named HOSTNAME: bash sets that variable itself, so ${HOSTNAME:-archmsi} would
# silently resolve to the live USB's hostname ("archiso") and the default would never
# apply. Use ARCH_HOSTNAME= to override.
ARCH_HOSTNAME=${ARCH_HOSTNAME:-archmsi}
USERNAME=${USERNAME:-arch}

red() { printf '\033[31m%s\033[0m\n' "$*"; }
grn() { printf '\033[32m%s\033[0m\n' "$*"; }
ylw() { printf '\033[33m%s\033[0m\n' "$*"; }

[[ -f /etc/arch-release ]] || { red "Not inside the Arch chroot."; exit 1; }
mountpoint -q /boot/efi || { red "/boot/efi is not mounted inside the chroot."; exit 1; }

# --- locale / time / host -----------------------------------------------------
ln -sf "/usr/share/zoneinfo/$TZ_REGION" /etc/localtime
hwclock --systohc

sed -i 's/^#en_US.UTF-8/en_US.UTF-8/' /etc/locale.gen
locale-gen
echo 'LANG=en_US.UTF-8' > /etc/locale.conf
echo "$ARCH_HOSTNAME" > /etc/hostname
cat > /etc/hosts <<EOF
127.0.0.1	localhost
::1		localhost
127.0.1.1	$ARCH_HOSTNAME.localdomain	$ARCH_HOSTNAME
EOF
grn "Locale, clock, hostname set ($TZ_REGION, $ARCH_HOSTNAME)."

# Windows keeps the RTC in local time; without this the two OSes fight over the clock.
timedatectl set-local-rtc 0 2>/dev/null || true

# --- users --------------------------------------------------------------------
if ! id "$USERNAME" &>/dev/null; then
  useradd -m -G wheel,video,audio,storage "$USERNAME"
  grn "Created user '$USERNAME'."
fi
sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers
grep -q '^%wheel ALL=(ALL:ALL) ALL' /etc/sudoers && grn "wheel sudo enabled." || ylw "Check /etc/sudoers manually."

systemctl enable NetworkManager

ylw "Set the root password:";      passwd
ylw "Set the password for $USERNAME:"; passwd "$USERNAME"

# --- GRUB ---------------------------------------------------------------------
grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=Arch

# The single most common dual-boot mistake: os-prober disabled -> no Windows entry.
if grep -q '^#\?GRUB_DISABLE_OS_PROBER' /etc/default/grub; then
  sed -i 's/^#\?GRUB_DISABLE_OS_PROBER=.*/GRUB_DISABLE_OS_PROBER=false/' /etc/default/grub
else
  echo 'GRUB_DISABLE_OS_PROBER=false' >> /etc/default/grub
fi

# nvidia_drm.modeset=1 now, so the NVIDIA step later needs no second kernel-line edit.
sed -i 's/^GRUB_CMDLINE_LINUX_DEFAULT=.*/GRUB_CMDLINE_LINUX_DEFAULT="loglevel=3 quiet nvidia_drm.modeset=1"/' /etc/default/grub

grn "/etc/default/grub:"
grep -E 'OS_PROBER|CMDLINE_LINUX_DEFAULT' /etc/default/grub

grub-mkconfig -o /boot/grub/grub.cfg 2>&1 | tee /tmp/grub-mkconfig.log

echo
if grep -qi 'Windows Boot Manager' /tmp/grub-mkconfig.log; then
  grn "=============================================="
  grn " Found Windows Boot Manager - dual boot is OK"
  grn "=============================================="
else
  red "=================================================================="
  red " Windows Boot Manager was NOT found."
  red " Do NOT reboot expecting a Windows entry. Fix this first:"
  red "   - confirm GRUB_DISABLE_OS_PROBER=false in /etc/default/grub"
  red "   - confirm /boot/efi/EFI/Microsoft/Boot/bootmgfw.efi exists"
  red "   - pacman -S os-prober, then re-run grub-mkconfig -o /boot/grub/grub.cfg"
  red " You can always boot Windows from the firmware menu (F11) meanwhile."
  red "=================================================================="
fi

cat <<'EOF'

Then:
    exit
    umount -R /mnt
    reboot        # pull the USB out

After first boot into Arch, run:  /root/04-nvidia.sh
EOF
