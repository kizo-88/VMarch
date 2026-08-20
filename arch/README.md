# Arch-side install scripts (steps 5–9)

These run **on the Arch live USB / the installed Arch system**, never on Windows.
They automate [`../DUALBOOT.md`](../DUALBOOT.md) steps 5–9 with the guard rails that
document only states in prose.

## Getting them onto the live USB

They live on the Windows partition, which the live USB can read. After booting the
installer:

```bash
mkdir -p /mnt/win
mount -o ro /dev/nvme0n1p3 /mnt/win          # p3 = C:
cp -r /mnt/win/.DEVELOPER/dualboot/VMarch/arch /root/arch
umount /mnt/win
cd /root/arch && chmod +x *.sh
```

If `mount` refuses with a dirty-NTFS error, Windows was not shut down cleanly — reboot
into Windows, shut down fully (Fast Startup is already off, so a normal shutdown is
enough), and come back. Or just copy the folder onto the USB stick from Windows first.

## Order

| Script | Where | Does |
|---|---|---|
| `01-partition.sh` | live USB, root | Verifies p1–p5 + the Windows loader on the ESP, walks you through `cfdisk`, formats **only** the new partition |
| `02-install.sh` | live USB, root | Mounts root + the shared ESP, `pacstrap`, `genfstab` |
| `03-chroot.sh` | inside `arch-chroot /mnt` | Locale, host, users, GRUB, `GRUB_DISABLE_OS_PROBER=false`, verifies the Windows entry |
| `04-nvidia.sh` | installed Arch, after reboot | NVIDIA Optimus, early KMS, laptop extras |

```bash
./01-partition.sh          # run, do the cfdisk it prints, run it again
./02-install.sh
arch-chroot /mnt
/root/03-chroot.sh
exit; umount -R /mnt; reboot
# then, in Arch:
/root/04-nvidia.sh
```

## What the guards refuse to do

`01-partition.sh` and `02-install.sh` abort rather than continue if:

- the machine is not booted in UEFI mode
- any of `p1`–`p5` is missing (layout is not what the plan describes)
- `p2` does not contain `EFI/Microsoft/Boot/bootmgfw.efi` (wrong ESP)
- the format target resolves to `p1`–`p5`
- the target is smaller than 20 GB, or already holds NTFS
- more than one non-Windows partition exists and no `TARGET=` was given
- you type anything other than `YES` at the format prompt

`03-chroot.sh` prints a loud failure if `grub-mkconfig` does not report
**"Found Windows Boot Manager"**, because that is the point where a dual boot silently
becomes a single boot.

## Overrides

```bash
TARGET=/dev/nvme0n1p7 ./01-partition.sh      # pick the partition explicitly
TZ_REGION=Europe/Berlin ARCH_HOSTNAME=box USERNAME=me /root/03-chroot.sh
```
