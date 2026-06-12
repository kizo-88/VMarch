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

## PART 2 (2026-06-12) — Hyprland, swww, pywal, Brave, Chrome

All five installed and verified running. **The VM now boots straight into Hyprland as user `arch` / password `arch`.**

### What was installed
| Package | Source | Notes |
|---|---|---|
| `hyprland` 0.55 | official repo | + xdg-desktop-portal-hyprland, qt5/qt6-wayland |
| `swww` 0.9.5 | AUR (built from source) | wallpaper daemon |
| `python-pywal` | official repo | `wal` command |
| `brave-bin` | AUR | Brave browser |
| `google-chrome` | AUR | Chrome browser |
| extras | official repo | kitty, waybar, wofi, mako, grim, slurp, polkit-gnome, yay (AUR helper) |

### Key fixes discovered along the way
1. **Slow mirror stalled pacman** → replaced `/etc/pacman.d/mirrorlist` with Cloudflare/kernel.org mirrors.
2. **yay swapped swww for the `awww` fork** → removed it, built genuine `swww` from AUR directly.
3. **swww compile OOM-killed at 2 GB RAM** → added a permanent 4 GB `/swapfile` + single-job build.
4. **Hyprland refuses to run as root** → created normal user **`arch` / `arch`** (wheel + sudo); LightDM autologin → Hyprland session.
5. **Graphics:** enabled VirtualBox **3D acceleration** + bumped VM RAM to **4096 MB**; blacklisted `vboxvideo` (conflicts with `vmwgfx` on VMSVGA).
6. **pywal needs a colorful image** → plain gradients fail palette extraction; generated plasma-fractal wallpaper at `~/Pictures/wall.png`.
7. **swww socket** is per-display: use `WAYLAND_DISPLAY=wayland-1` when calling `swww` from outside the session.

### Logins
| Account | Password | Use |
|---|---|---|
| `arch` | `arch` | **default** — autologin into Hyprland, has sudo |
| `root` | `arch` | console/maintenance |

### Hyprland keybinds (in `~/.config/hypr/hyprland.conf`)
- **Super+Enter** terminal (kitty) • **Super+D** app launcher (wofi)
- **Super+B** Brave • **Super+C** Chrome
- **Super+Q** close window • **Super+F** fullscreen • **Super+Shift+E** exit to login
- **Super+1/2/3** switch workspace • **Super+Shift+1/2/3** move window to workspace
- Wallpaper: `swww img <file>` • Colors: `wal -i <file>`

XFCE is still installed — log out (Super+Shift+E) and pick it in the greeter's session menu if wanted.

## PART 3 (2026-06-12) — The "rice": fastfetch + zsh + transparent terminal

Goal: replicate the classic `arch + hyprland + swww + pywal` aesthetic (transparent terminal
with fastfetch over a moody wallpaper, colors generated from the wallpaper).

### Added
- **fastfetch** — system-info splash, runs automatically when a terminal opens
- **zsh** (now the default shell for `arch`) + autosuggestions + syntax-highlighting plugins
- **JetBrainsMono Nerd Font** (`ttf-jetbrains-mono-nerd`)
- **foot** terminal — transparent (alpha 0.85), nerd font, padded
- **Wallpaper:** `misty_mountains.jpg` from the nordic-wallpapers repo → `~/Pictures/wall.png`,
  applied with swww; pywal palette regenerated from it
- Hyprland: blur + rounding enabled (`decoration { blur { ... } }`)

### Why foot and not kitty
kitty 0.47's Wayland backend crashes on this VM stack (`wl_surface.attach invalid arguments`,
even with default config), and its X11 fallback needs XWayland, which the session doesn't start.
**foot** is Wayland-native and CPU-rendered — ideal for VMs — and does the same transparent look.
kitty stays installed (Super-key bind switched to foot).

### Files
| File (in VM) | Purpose |
|---|---|
| `/home/arch/.config/foot/foot.ini` | font, padding, `[colors-dark]` alpha 0.85, shell=zsh |
| `/home/arch/.zshrc` | pywal sequences, prompt, plugins, fastfetch-on-open |
| `/home/arch/.config/hypr/hyprland.conf` | blur/rounding, Super+Enter → foot |
| `/home/arch/Pictures/wall.png` | the wallpaper (swww + pywal source) |

### Change the look later (inside the VM)
```bash
swww img ~/Pictures/newwall.png   # set wallpaper
wal -i ~/Pictures/newwall.png -n  # regenerate colors from it
```

## PART 4 (2026-06-12) — Taskbar, dock, and app drawer

### Added
- **Taskbar (top):** waybar rethemed — floating rounded "pill" modules, pywal colors
  (`@import` of `~/.cache/wal/colors-waybar.css`): workspaces, window title, clock,
  CPU, RAM, network, system tray. Config: `~/.config/waybar/{config.jsonc,style.css}`.
- **Dock (bottom):** `nwg-dock-hyprland` with real app icons — pinned: foot, Thunar,
  Brave, Chrome (pins in `~/.cache/nwg-dock-pinned`) + a launcher-grid button + running apps.
- **App drawer:** `nwg-drawer` — fullscreen searchable app grid with categories
  ("apps appear on the desktop"). Open with **Super+A**, the dock grid button, or Esc to close.
- **Papirus-Dark icon theme** (`~/.config/gtk-3.0/settings.ini`) for proper app icons.

### New keybinds
- **Super+A** → app drawer • **Super+E** → Thunar file manager
- Both autostart with the session (`exec-once` in hyprland.conf).

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
