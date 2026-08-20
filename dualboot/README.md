# Dual-boot Arch alongside Windows 11 — Dell Precision 3640

Scripts for the bare-metal install. Full runbook with the firmware steps lives in the
artifact; this directory is only the part that runs inside the Arch installer.

## This machine

| | |
|---|---|
| Disk | single 953.9 GB NVMe (`/dev/nvme0n1`), GPT |
| Firmware | UEFI, Secure Boot **on** (must be disabled to boot the installer) |
| Controller | **Intel RST / RAID mode** — the installer may not see the disk at all |
| ESP | `p1`, only 150 MB — too small for kernels, hence GRUB rather than systemd-boot |
| Existing | `p1` ESP · `p2` MSR · `p3` Windows NTFS · `p4`/`p5` recovery |
| New | `p6` — created by you in cfdisk, from space shrunk off C: |

## Order of operations

1. **In Windows** — check BitLocker (`manage-bde -status C:`), save the recovery key,
   suspend it. Then `powercfg /h off` and shrink C: by 204800 MB in `diskmgmt.msc`.
   Leave the freed space **unallocated**.
2. **Write the USB** — `rufus-4.15p.exe` in `C:\.Developer\VM\`, **DD Image mode**, GPT/UEFI.
3. **Boot it** — F2 to disable Secure Boot, F12 to pick the UEFI USB entry.
4. **Test before changing firmware** — run `lsblk`. If `nvme0n1` appears, skip step 5.
5. **Only if no disk** — the RAID→AHCI switch, via the Safe Mode procedure in the runbook.
   Getting this wrong bluescreens Windows; it is reversible by setting RAID On again.
6. **Partition** — `cfdisk /dev/nvme0n1`, select the free space, New, type
   *Linux filesystem*, Write, Quit. It becomes `p6`.
7. **Install** — the two scripts below.

## Getting these scripts into the installer

The installer has networking, so the simplest route is to fetch them:

```bash
curl -O https://raw.githubusercontent.com/kizo-88/VMarch/main/dualboot/01-install.sh
curl -O https://raw.githubusercontent.com/kizo-88/VMarch/main/dualboot/02-configure.sh
chmod +x 01-install.sh 02-configure.sh
```

(That works once this directory is pushed to the repo.)

## Running them

```bash
./01-install.sh                    # defaults to /dev/nvme0n1p6
./01-install.sh /dev/nvme0n1p7     # or name a different target
```

`01-install.sh` will **refuse to run** unless it can prove it is on the right machine:
it verifies UEFI boot, that `p1` is vfat and contains `EFI/Microsoft`, that `p3` is NTFS,
that the target is not one of `p1`–`p5`, is unmounted, and is between 40 and 400 GB.
It then asks you to type `ERASE`. It formats only the partition you named; `p1` is
mounted read-write for GRUB but never reformatted.

Then:

```bash
arch-chroot /mnt
/root/02-configure.sh
```

Override the defaults with environment variables if you want:

```bash
TZ=Europe/Dublin LOCALE=en_IE.UTF-8 HOSTNAME=arch USERNAME=kizo /root/02-configure.sh
```

`02-configure.sh` sets time/locale/host, creates your user, installs GRUB, enables
`os-prober`, and **tells you whether the Windows entry was actually found** — the single
most common dual-boot failure.

Finally:

```bash
exit
umount -R /mnt
reboot            # pull the USB out as it restarts
```

## After first boot

```bash
sudo pacman -S nvidia nvidia-utils nvidia-settings   # RTX 3080
```

And in Windows, so the two systems stop fighting over the clock:

```
reg add "HKLM\SYSTEM\CurrentControlSet\Control\TimeZoneInformation" /v RealTimeIsUniversal /t REG_DWORD /d 1 /f
```

Resume BitLocker (`Resume-BitLocker -MountPoint "C:"`) once both systems boot cleanly.
Leave Fast Startup **off** permanently, or the Windows partition becomes unsafe to mount
from Linux.

## Rolling back

Delete `p6` in Windows Disk Management, extend C: back over it, then remove the firmware
entry with `bcdedit /enum firmware` and `bcdedit /delete "{guid}"`. Windows is untouched
throughout — nothing here writes to `p1`–`p5` except adding `\EFI\Arch` to the ESP.
