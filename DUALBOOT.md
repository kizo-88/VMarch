# Dual-boot Arch Linux alongside Windows 11 — MSI GF63 Thin 10SC

This document covers a **real dual-boot install on bare metal**. It is not related to the
VM setup in [`SETUP-LOG.md`](SETUP-LOG.md) — that VM is an **MBR/BIOS** disk running under
VirtualBox/QEMU, which is the opposite of what this machine needs. Do not mix the two.

> **Read the "where does this run" label on every section.** Commands marked
> **[Windows]** run in Windows PowerShell. Commands marked **[Arch live USB]** only work
> after you have booted the installer — they do not exist on Windows. Pasting
> `mount /dev/nvme0n1p6 /mnt` into PowerShell hits the `New-PSDrive` alias and hangs at a
> `Root:` prompt.

---

## The target machine

Verified on 2026-08-18:

| | |
|---|---|
| Model | MSI GF63 Thin 10SC |
| CPU | Intel i5-10300H — **4 cores / 8 threads** |
| RAM | 20 GB |
| GPU | **NVIDIA GTX 1650 Max-Q + Intel UHD (Optimus hybrid)** |
| Firmware | **UEFI**, GPT |
| Disk 1 | PNY CS1031 1 TB NVMe — `/dev/nvme0n1` |
| Disk 2 | 464 GB **Storage Spaces** (`D:`) |

### Disk 1 layout (before install)

| Part | Size | Purpose |
|---|---|---|
| p1 | 128 MB | Microsoft Reserved (MSR) |
| p2 | **300 MB** | **EFI System Partition** — shared with Arch |
| p3 | 912.4 GB | `C:` Windows |
| p4 | 0.9 GB | WinRE |
| p5 | 17.8 GB | MSI OEM recovery |

Three constraints follow from this:

1. **Disk 2 is unusable.** Storage Spaces is a Microsoft virtual-disk layer; Linux cannot
   read it. Arch must come out of Disk 1.
2. **The ESP is only 300 MB** — too small to hold Arch kernels next to Windows' boot files.
   Use **GRUB** (small stub in the ESP, kernels stay on the Linux root), *not* systemd-boot,
   which expects kernels inside the ESP.
3. **Never format p2**, and never touch p1, p4, or p5.

---

## Pre-flight state

| Check | Result | Action |
|---|---|---|
| BitLocker `C:` / `D:` | `FullyDecrypted`, no key protectors | ✅ none — nothing to suspend |
| Fast Startup | `HiberbootEnabled = 0` | ✅ already off |
| Secure Boot | **enabled** | ⚠️ must disable in firmware |
| Max shrink on `C:` | **149.45 GB** | ✅ measured elevated 2026-08-19 |
| Arch ISO | `C:\.DEVELOPER\VM\archlinux.iso`, 2026.08.01, SHA256 verified | ✅ ready |

### About the shrink limit

`C:` has 210 GB free and Windows will release **149.45 GB** of it. Free space is never the
whole story — *immovable files* cap the shrink, and the partition cannot shrink past the
outermost one. Here that cap is generous.

> The 54.1 GB figure recorded on 2026-08-18 was wrong. `Get-PartitionSupportedSize` on this
> 912 GB volume takes **~6 minutes** to return, and every earlier attempt was killed before
> it answered. Measured elevated on 2026-08-19: current 912.41 GB, minimum 762.97 GB →
> **max shrink 149.45 GB**. Re-measure with [`_maxshrink.ps1`](_maxshrink.ps1) (read-only)
> and let it finish.

149 GB is far more than Arch needs — the VM ran base Arch + Hyprland + the full BlackArch
toolkit in ~26 GB. **Shrink by 120 GB**: a comfortable Arch partition that still leaves
~90 GB free on `C:` and does not push against the limit.

The usual "reclaim more space" advice does not apply on this machine and should be skipped:

- **Pagefile** — lives on `D:` (`D:\pagefile.sys`, 14 GB). `C:` has none to move.
- **Hibernation** — already off, `hiberfil.sys` absent. `powercfg /h off` is a no-op.

Only **shadow copies** remain as a lever, and only if you want more than 149 GB. Two exist
(2026-08-18 and 2026-08-19). Deleting them destroys those System Restore points, so leave
them alone unless you actually need the extra space **[Windows, elevated]**:

```powershell
vssadmin delete shadows /all /quiet
```

---

## Step 1 — Shrink `C:` **[Windows]**

Use **`diskmgmt.msc`** → right-click `C:` → **Shrink Volume** → enter **`122880`** MB
(120 GB) → **Shrink**. Do this from Windows, not from Linux, so NTFS metadata stays
consistent.

Disk Management estimates the shrinkable amount with a quicker, more pessimistic check than
`Get-PartitionSupportedSize`; if it offers less than 122880 MB, type the number anyway.

**Leave the freed space unallocated.** Do not create a volume in it — the Arch installer
will do that.

The free space lands between `C:` and the recovery partitions. That is expected and fine.

## Step 2 — Disable Secure Boot **[firmware]**

The Arch ISO is unsigned and will not boot with Secure Boot on.

Reboot → tap **Del** at the MSI splash → Security → **Secure Boot → Disabled** → F10 to save.

## Step 3 — Write the USB **[Windows]**

Plug in an 8 GB+ stick (**it will be erased**), then write `C:\.DEVELOPER\VM\archlinux.iso`
with [Rufus](https://rufus.ie): Partition scheme **GPT**, target system **UEFI (non-CSM)**.
Ventoy works too.

## Step 4 — Boot the installer **[firmware]**

Reboot → tap **F11** → pick the USB under UEFI. You land at a root prompt.

Connect to wifi:

```bash
iwctl
# station wlan0 connect <SSID>
# exit
ping -c3 archlinux.org
```

---

## Step 5 — Partition **[Arch live USB]**

**Confirm the layout before touching anything:**

```bash
lsblk
fdisk -l /dev/nvme0n1
```

You should see p1–p5 and a block of free space. Then:

```bash
cfdisk /dev/nvme0n1
```

Select the **Free space** entry → `New` → accept the full size → type stays
`Linux filesystem` → `Write` → type `yes` → `Quit`.

Note the new partition's number — it is most likely **p6**, but **verify with `lsblk`**
rather than assuming. Everything below writes `p6`; substitute what you actually got.

```bash
mkfs.ext4 /dev/nvme0n1p6
```

> Only `mkfs` the new partition. Running `mkfs` on p2 destroys the Windows boot loader.

## Step 6 — Mount, reusing the Windows ESP **[Arch live USB]**

```bash
mount /dev/nvme0n1p6 /mnt
mkdir -p /mnt/boot/efi
mount /dev/nvme0n1p2 /mnt/boot/efi
```

## Step 7 — Install the base system **[Arch live USB]**

```bash
pacstrap -K /mnt base linux linux-firmware intel-ucode grub efibootmgr os-prober \
    networkmanager nano sudo
genfstab -U /mnt >> /mnt/etc/fstab
arch-chroot /mnt
```

Everything from here runs **inside the chroot**.

```bash
ln -sf /usr/share/zoneinfo/Asia/Kuala_Lumpur /etc/localtime   # adjust to your zone
hwclock --systohc
sed -i 's/^#en_US.UTF-8/en_US.UTF-8/' /etc/locale.gen
locale-gen
echo 'LANG=en_US.UTF-8' > /etc/locale.conf
echo 'archmsi' > /etc/hostname
passwd
useradd -m -G wheel,video,audio arch
passwd arch
EDITOR=nano visudo        # uncomment: %wheel ALL=(ALL:ALL) ALL
systemctl enable NetworkManager
```

## Step 8 — GRUB, and making Windows appear **[chroot]**

```bash
grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=Arch
```

Edit `/etc/default/grub` and **uncomment**:

```
GRUB_DISABLE_OS_PROBER=false
```

Without this, os-prober is skipped and **Windows will not appear in the boot menu.** This is
the single most common dual-boot mistake.

While in that file, add the NVIDIA kernel parameter (see next section):

```
GRUB_CMDLINE_LINUX_DEFAULT="loglevel=3 quiet nvidia_drm.modeset=1"
```

Then:

```bash
grub-mkconfig -o /boot/grub/grub.cfg
```

Confirm the output mentions **"Found Windows Boot Manager"**. If it does not, Windows will
not be bootable from GRUB — stop and fix it before rebooting.

```bash
exit
umount -R /mnt
reboot
```

Remove the USB. You should get a GRUB menu with **Arch Linux** and **Windows Boot Manager**.

---

## Step 9 — NVIDIA Optimus

This is the part the VM setup has nothing to say about, and where most installs on this
laptop stall. The GF63 Thin has **no MUX switch** — you cannot disable the iGPU in firmware,
so both GPUs are always present.

```bash
sudo pacman -S nvidia nvidia-utils lib32-nvidia-utils nvidia-prime \
    mesa intel-media-driver
```

GTX 1650 is Turing, fully supported by the current `nvidia` driver.

Add the modules to `/etc/mkinitcpio.conf`:

```
MODULES=(nvidia nvidia_modeset nvidia_uvm nvidia_drm)
```

```bash
sudo mkinitcpio -P
```

`nvidia_drm.modeset=1` was already added to the kernel line in step 8. Run an app on the
dGPU with `prime-run <app>`.

### If you want the repo's Hyprland rice

[`rice2-setup.sh`](rice2-setup.sh) and friends work on bare metal, but they were written for
a VM. Before running them:

- **Drop** `virtualbox-guest-utils` and the `vboxservice` unit — meaningless here
- **Do not** blacklist `vboxvideo` (`SETUP-LOG.md:176`) — that was a VMSVGA workaround
- Hyprland on Optimus needs these in the session environment:

```
env = LIBVA_DRIVER_NAME,nvidia
env = __GLX_VENDOR_LIBRARY_NAME,nvidia
env = NVD_BACKEND,direct
```

- `kitty` was dropped for `foot` because kitty crashed on the VM's Wayland stack
  (`SETUP-LOG.md:209-212`). On real hardware kitty works fine — that substitution is
  no longer necessary.

### Laptop extras worth having

```bash
sudo pacman -S power-profiles-daemon brightnessctl bluez bluez-utils
sudo systemctl enable --now power-profiles-daemon bluetooth
```

---

## If Windows stops booting

Nothing here deletes the Windows boot loader, but if GRUB does not offer Windows:

1. Boot the Arch USB, `mount /dev/nvme0n1p2 /mnt` and confirm
   `/mnt/EFI/Microsoft/Boot/bootmgfw.efi` still exists. If it does, Windows is intact and
   only the GRUB menu is wrong — re-run `grub-mkconfig` with `GRUB_DISABLE_OS_PROBER=false`.
2. The firmware boot menu (**F11**) lists both loaders independently of GRUB, so you can
   always boot Windows directly from there.
3. Windows Update occasionally re-asserts its own boot entry. Re-run
   `sudo grub-mkconfig -o /boot/grub/grub.cfg` from Arch if the menu changes.

## Things not to do

- Do not shrink or repartition **Disk 2** — Storage Spaces, unreadable by Linux.
- Do not format **p2** (ESP), **p4** (WinRE), or **p5** (MSI recovery).
- Do not re-enable Fast Startup — it leaves NTFS in a dirty state that Linux will refuse to
  mount read-write. It is currently off; keep it off.
- Do not copy the VM tuning from `SETUP-LOG.md:247-254` — that log was written on a
  different host (i7-10700, 8C/16T, 15.7 GB). `--cpus 10` exceeds this CPU's 8 threads.
