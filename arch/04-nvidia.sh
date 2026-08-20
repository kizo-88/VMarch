#!/usr/bin/env bash
# Step 9 - NVIDIA Optimus (GTX 1650 Max-Q + Intel UHD) and laptop extras.
# Run from the installed Arch system after the first reboot, as a normal user with sudo.
set -euo pipefail

grn() { printf '\033[32m%s\033[0m\n' "$*"; }
ylw() { printf '\033[33m%s\033[0m\n' "$*"; }
red() { printf '\033[31m%s\033[0m\n' "$*"; }

[[ -f /etc/arch-release ]] || { red "Not on Arch."; exit 1; }
[[ $EUID -ne 0 ]] || ylw "Running as root is fine, but this is written for 'sudo'."

SUDO=""; [[ $EUID -ne 0 ]] && SUDO=sudo

# The GF63 Thin 10SC has no MUX switch - both GPUs are always live.
lspci -nn | grep -Ei 'vga|3d' || true

$SUDO pacman -Syu --noconfirm

# GTX 1650 is Turing - the current proprietary driver supports it fully.
$SUDO pacman -S --noconfirm \
  nvidia nvidia-utils lib32-nvidia-utils nvidia-prime \
  mesa lib32-mesa intel-media-driver vulkan-intel

# --- early KMS ----------------------------------------------------------------
if ! grep -q 'nvidia_drm' /etc/mkinitcpio.conf; then
  $SUDO sed -i 's/^MODULES=.*/MODULES=(nvidia nvidia_modeset nvidia_uvm nvidia_drm)/' /etc/mkinitcpio.conf
fi
grn "mkinitcpio MODULES:"; grep '^MODULES=' /etc/mkinitcpio.conf
$SUDO mkinitcpio -P

# nvidia_drm.modeset=1 was already put on the kernel line in 03-chroot.sh.
grep -q 'nvidia_drm.modeset=1' /etc/default/grub \
  && grn "nvidia_drm.modeset=1 already on the kernel line." \
  || { ylw "Adding nvidia_drm.modeset=1"; \
       $SUDO sed -i 's/^GRUB_CMDLINE_LINUX_DEFAULT="\(.*\)"/GRUB_CMDLINE_LINUX_DEFAULT="\1 nvidia_drm.modeset=1"/' /etc/default/grub; \
       $SUDO grub-mkconfig -o /boot/grub/grub.cfg; }

# --- laptop extras ------------------------------------------------------------
$SUDO pacman -S --noconfirm power-profiles-daemon brightnessctl bluez bluez-utils
$SUDO systemctl enable --now power-profiles-daemon bluetooth

# --- Windows entry re-check ---------------------------------------------------
# Windows Update sometimes re-asserts its own boot entry.
$SUDO grub-mkconfig -o /boot/grub/grub.cfg 2>&1 | grep -i 'windows' \
  && grn "Windows still in the GRUB menu." \
  || red "Windows entry missing - see 'If Windows stops booting' in DUALBOOT.md"

cat <<'EOF'

Reboot, then verify:
    nvidia-smi                 # driver loaded
    prime-run glxinfo | grep "OpenGL renderer"   # should say NVIDIA

For the Hyprland rice in this repo (rice2-setup.sh), first:
  - drop virtualbox-guest-utils and the vboxservice unit
  - do NOT blacklist vboxvideo
  - keep kitty (the switch to foot was a VM-only workaround)
  - add to hyprland.conf:
        env = LIBVA_DRIVER_NAME,nvidia
        env = __GLX_VENDOR_LIBRARY_NAME,nvidia
        env = NVD_BACKEND,direct
EOF
