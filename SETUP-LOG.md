# Arch Linux VM — Full Setup Log

**Date:** 2026-06-11
**Host:** Windows 11 Pro
**VM directory:** `C:\.Developer\VM`
**Result:** Arch Linux boots into a graphical XFCE desktop in both VirtualBox (Oracle) and QEMU.

---

## Credentials

| | |
|---|---|
| **Login user** | `root` |
| **Password** | `arch` |

> Only one account exists. To change the password later, open a terminal in the VM and run `passwd`.

---

## Key facts about this VM

- **Disk:** `C:\.Developer\VM\arch.vdi` — 20 GB, **MBR/BIOS** layout:
  - Partition 1: 1 GB FAT32 (boot flag) = `/boot`
  - Partition 2: ~19 GB ext4 = `/` (root, `/dev/sda2`)
  - GRUB bootloader installed in the MBR.
- **CRITICAL:** the VM **must use BIOS firmware, NOT EFI.** An EFI VM will not boot this disk. (The original `setup-vbox.ps1` wrongly set `--firmware efi` — that was the main reason it "couldn't open.")
- **Network interface inside the VM:** `enp0s3` (VirtualBox NAT, IP `10.0.2.15`).
- **Never run VirtualBox and QEMU against `arch.vdi` at the same time** — only one writer, or the filesystem corrupts.

---

## STEP 1 — Diagnose why it wouldn't boot

1. Listed the VM folder; found `arch.vdi` (2.1 GB used), `archlinux.iso`, QEMU binaries, and the PowerShell scripts.
2. Inspected the disk with `qemu-img info` → valid 20 GB VDI.
3. Read the partition table → MBR with FAT32 `/boot` + ext4 root, **GRUB present in MBR**. So the disk was a complete BIOS-mode install.
4. Checked VirtualBox: `VBoxManage list vms` → VM `ArchLinux-VM` was registered.
5. **Found the bug:** the VM (and `setup-vbox.ps1`) firmware was/should be **BIOS**, the install ISO was not attached, but firmware mismatch (EFI vs the BIOS disk) was the blocker.

## STEP 2 — Boot test in VirtualBox (Oracle)

```powershell
& "C:\Program Files\Oracle\VirtualBox\VBoxManage.exe" startvm "ArchLinux-VM" --type gui
```
- GRUB appeared → kernel + initramfs loaded → reached `archlinux login:`.
- **VirtualBox boots Arch correctly.**

## STEP 3 — Boot test in QEMU

Powered off the VBox VM first (to release the disk lock), then:
```powershell
C:\.Developer\VM\qemu\qemu-system-x86_64.exe -m 2048 -smp 2 `
  -drive file=C:\.Developer\VM\arch.vdi,format=vdi -boot c `
  -net nic -net user -accel whpx -accel tcg
```
- Also reached `archlinux login:`. **QEMU boots Arch correctly too.**

## STEP 4 — Fix the helper scripts

- **`setup-vbox.ps1`** — changed `--firmware efi` → **`--firmware bios`**, made it safe to re-run (unregister/recreate without deleting the disk), attach the existing disk instead of creating a new one, boot order = disk first.
- **`run-vm.ps1`** — use explicit `-drive file=...,format=vdi`, BIOS boot, WHPX accel with TCG fallback.

---

## STEP 5 — Reset the lost password

The old password was unrecoverable (only a one-way hash on disk), so it was reset using the Arch live ISO:

1. Attached the ISO and set DVD as first boot device:
   ```powershell
   VBoxManage storageattach "ArchLinux-VM" --storagectl "IDE Controller" --port 0 --device 0 --type dvddrive --medium "C:\.Developer\VM\archlinux.iso"
   VBoxManage modifyvm "ArchLinux-VM" --boot1 dvd --boot2 disk
   ```
2. Booted the ISO → it auto-logs into a passwordless root shell (`root@archiso`).
3. Inside the live shell:
   ```bash
   mount /dev/sda2 /mnt
   grep -E 'bash|zsh|:/home' /mnt/etc/passwd   # -> only: root:x:0:0::/root:/usr/bin/bash
   echo 'root:arch' | chpasswd -R /mnt          # set root password to "arch"
   sync; umount /mnt
   ```
4. Detached the ISO and restored disk-first boot:
   ```powershell
   VBoxManage storageattach "ArchLinux-VM" --storagectl "IDE Controller" --port 0 --device 0 --type dvddrive --medium emptydrive
   VBoxManage modifyvm "ArchLinux-VM" --boot1 disk --boot2 none
   ```
5. Rebooted and confirmed login with `root` / `arch` → got `[root@archlinux ~]#`.

---

## STEP 6 — Fix networking (was disabled)

The base install had **no network enabled** (`enp0s3` was DOWN, DNS failed). Fixed with systemd-networkd so it persists:

```bash
ip link set enp0s3 up
printf '[Match]\nName=enp0s3\n\n[Network]\nDHCP=yes\n' > /etc/systemd/network/20-wired.network
systemctl enable --now systemd-networkd systemd-resolved
ln -sf /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf
```
Verified: `enp0s3` got IP `10.0.2.15`, and `ping archlinux.org` resolved successfully.

---

## STEP 7 — Install the graphical desktop (XFCE)

```bash
pacman -Sy --noconfirm archlinux-keyring
pacman -Syu --needed --noconfirm \
    xorg-server xorg-xinit xfce4 lightdm lightdm-gtk-greeter virtualbox-guest-utils
```
(~191 packages, ~300 MB downloaded.)

What each part is for:
- `xorg-server`, `xorg-xinit` — the X display server
- `xfce4` — the desktop environment
- `lightdm`, `lightdm-gtk-greeter` — graphical login screen
- `virtualbox-guest-utils` — VirtualBox display/resolution/clipboard integration

---

## STEP 8 — Enable graphical login + reboot

```bash
# Use the GTK greeter
sed -i 's/^#\?greeter-session=.*/greeter-session=lightdm-gtk-greeter/' /etc/lightdm/lightdm.conf

# Start the graphical login on boot + the VirtualBox guest service
systemctl enable lightdm vboxservice

# Reboot
systemctl reboot
```

After reboot: the **LightDM graphical login** appeared, logging in with `root` / `arch` loaded the **full XFCE desktop** (Applications menu, Home / File System icons, panel, clock, dock). ✅

---

## How to start the VM in the future

**VirtualBox (recommended):**
```powershell
& "C:\Program Files\Oracle\VirtualBox\VBoxManage.exe" startvm "ArchLinux-VM" --type gui
```
or just open the VirtualBox app and press **Start** on `ArchLinux-VM`.

**QEMU:**
```powershell
powershell -ExecutionPolicy Bypass -File C:\.Developer\VM\run-vm.ps1
```

> Reminder: run only **one** of them at a time against `arch.vdi`.

---

## Useful things you might want next

- **Create a normal (non-root) user** (recommended for daily use):
  ```bash
  useradd -m -G wheel,video,audio username
  passwd username
  pacman -S --noconfirm sudo
  EDITOR=nano visudo      # uncomment: %wheel ALL=(ALL:ALL) ALL
  ```
- **Install a web browser:** `pacman -S --noconfirm firefox`
- **Shared clipboard / drag-and-drop:** already enabled via `vboxservice`; in the VirtualBox menu set *Devices → Shared Clipboard → Bidirectional*.
- **Change the password:** run `passwd` in a terminal.
