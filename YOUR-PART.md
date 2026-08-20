# Your part — everything left to finish the dual boot

Windows-side work is finished. Written 2026-08-20.

**Already done for you:** `C:` shrunk (120 GB unallocated and waiting), Arch ISO verified
against Arch's official checksum, installer written to the Samsung and verified byte-for-byte,
install scripts reviewed and fixed.

**Reading this from the live USB?** It lives on your Windows partition:
`/mnt/win/.DEVELOPER/dualboot/VMarch/YOUR-PART.md` after step 4 below.

---

## 1. Disable Secure Boot  [firmware]

The Arch image is unsigned. With Secure Boot on, the drive will not boot at all.

1. Reboot
2. Tap **Del** repeatedly at the MSI splash
3. **Security** → **Secure Boot** → **Disabled**
4. **F10** → save & exit

## 2. Boot the installer  [firmware]

Leave the Samsung plugged in.

1. Reboot, tap **F11** repeatedly
2. Pick the Samsung under the **UEFI** heading

> **This matters.** If the same drive is listed twice, take the **UEFI** one. Booting the
> legacy/BIOS entry produces an install that cannot boot alongside Windows.

You land at a root prompt: `root@archiso ~ #`

## 3. Connect wifi  [live USB]

```bash
iwctl
```

At the `[iwd]#` prompt:

```
station wlan0 connect YOUR_SSID
```

Enter the password, then `exit`. Confirm:

```bash
ping -c3 archlinux.org
```

Nothing works without this — `pacstrap` downloads the whole system.

## 4. Copy the scripts across  [live USB]

```bash
mkdir -p /mnt/win
mount -o ro /dev/nvme0n1p3 /mnt/win
cp -r /mnt/win/.DEVELOPER/dualboot/VMarch/arch /root/arch
umount /mnt/win
cd /root/arch && chmod +x *.sh
```

If `mount` complains the NTFS is dirty, Windows was not shut down cleanly — reboot into
Windows, shut down properly, come back.

## 5. Partition  [live USB]

```bash
./01-partition.sh
```

It verifies p1–p5 and the Windows boot loader, then stops and tells you to run:

```bash
cfdisk /dev/nvme0n1
```

- highlight the **Free space** entry (**120 GB**)
- **New** → accept the full size → type stays `Linux filesystem`
- **Write** → type `yes` → **Quit**

Then re-run it and type **`YES`** when it asks to format:

```bash
./01-partition.sh
```

> It refuses to touch p1–p5, refuses anything under 20 GB, refuses NTFS, and refuses to
> guess if it finds more than one candidate. If it aborts, read what it says — do not
> work around it.

## 6. Install the base system  [live USB]

```bash
./02-install.sh
```

Long and unattended. Mounts your new partition, reuses the Windows ESP without formatting
it, then `pacstrap`.

## 7. Configure + GRUB  [chroot]

```bash
arch-chroot /mnt
/root/03-chroot.sh
```

**You will be asked to set two passwords** — root, then your user `arch`.

### The one thing to watch for

At the end it prints either:

```
 Found Windows Boot Manager - dual boot is OK      <- green, correct
```

or a red block saying Windows was **not** found. **Green: continue. Red: stop.** That line
is the difference between a dual boot and losing your Windows menu entry. Windows is still
bootable from **F11** regardless, so nothing is lost — but fix it before rebooting.

Then:

```bash
exit
umount -R /mnt
reboot
```

Unplug the Samsung as it reboots. You should get a GRUB menu with **Arch Linux** and
**Windows Boot Manager**.

## 8. NVIDIA + laptop extras  [in Arch]

```bash
/root/04-nvidia.sh
```

Reboot, then check:

```bash
nvidia-smi
prime-run glxinfo | grep "OpenGL renderer"
```

---

## Afterwards

**Reclaim the Samsung.** It is a 953 GB drive holding a 1523 MB installer. In Windows:
Disk Management → right-click disk 3's partition → **Delete Volume** → right-click the
unallocated space → **New Simple Volume** → NTFS. Plain volume — **not** Storage Spaces
(Linux cannot read Storage Spaces, and it was what blocked the flash in the first place).

**The clocks will disagree.** Arch keeps the RTC in UTC, Windows uses local time, so one of
them will be off by your UTC offset. Not a fault. Fix from Arch if it bothers you:

```bash
sudo timedatectl set-local-rtc 1 --adjust-system-clock
```

**Do not re-enable Fast Startup.** It leaves NTFS dirty and Linux will refuse to mount
`C:` read-write. It is off; keep it off.

## If Windows will not boot

It is almost certainly fine — nothing here deletes the Windows loader.

1. **F11** at boot lists both loaders independently of GRUB. Use it to get into Windows.
2. From Arch, re-run: `sudo grub-mkconfig -o /boot/grub/grub.cfg`
3. Windows Update sometimes re-asserts its own boot entry; re-run that same command.

See `DUALBOOT.md` → "If Windows stops booting".
