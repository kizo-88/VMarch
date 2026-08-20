#!/usr/bin/env bash
# Step 5 - create the Arch root partition and format it.  [Arch live USB only]
#
# This script REFUSES to touch p1-p5.  It formats exactly one partition, the one
# you created in the free space, after you confirm it by typing YES.
set -euo pipefail

DISK=/dev/nvme0n1

red()  { printf '\033[31m%s\033[0m\n' "$*"; }
grn()  { printf '\033[32m%s\033[0m\n' "$*"; }
ylw()  { printf '\033[33m%s\033[0m\n' "$*"; }

[[ $EUID -eq 0 ]] || { red "Run as root."; exit 1; }
[[ -b $DISK ]]    || { red "$DISK not found. Are you on the right machine?"; exit 1; }

# --- Sanity: this must be UEFI, and the Windows layout must be intact ----------
[[ -d /sys/firmware/efi ]] || { red "Not booted in UEFI mode. Reboot the USB via the UEFI entry."; exit 1; }

ylw "== Current layout =="
lsblk -o NAME,SIZE,FSTYPE,PARTTYPENAME,MOUNTPOINTS "$DISK"
echo
sgdisk -p "$DISK" 2>/dev/null || fdisk -l "$DISK"
echo

# The five Windows partitions must all still be there before we add a sixth.
for n in 1 2 3 4 5; do
  [[ -b ${DISK}p$n ]] || { red "${DISK}p$n missing - layout is not what DUALBOOT.md describes. STOP."; exit 1; }
done
grn "p1-p5 present."

# ESP must be p2 and must still hold the Windows boot loader.
mkdir -p /tmp/espchk
if mount "${DISK}p2" /tmp/espchk 2>/dev/null; then
  if [[ -f /tmp/espchk/EFI/Microsoft/Boot/bootmgfw.efi ]]; then
    grn "ESP p2 holds the Windows boot loader. Good - it will be reused, never formatted."
  else
    red "p2 does not contain EFI/Microsoft/Boot/bootmgfw.efi. Wrong partition. STOP."
    umount /tmp/espchk; exit 1
  fi
  umount /tmp/espchk
else
  red "Could not mount ${DISK}p2 to verify it. STOP."; exit 1
fi

# --- Create the partition -----------------------------------------------------
cat <<'EOF'

Now create the Linux partition in the free space:

    cfdisk /dev/nvme0n1

  * highlight the "Free space" entry
  * New -> accept the full size -> type stays "Linux filesystem"
  * Write -> type "yes" -> Quit

Then re-run this script. It will pick up the new partition.

EOF

# Find candidate: a partition >= 6 with a Linux filesystem type, or any part not 1-5.
mapfile -t NEW < <(lsblk -lno NAME "$DISK" | grep -E 'nvme0n1p[0-9]+$' | sed 's/^/\/dev\//' \
                   | grep -vE "p[1-5]$")

if [[ ${#NEW[@]} -eq 0 ]]; then
  ylw "No new partition yet. Run cfdisk as shown above, then re-run this script."
  exit 0
fi

if [[ ${#NEW[@]} -gt 1 && -z ${TARGET:-} ]]; then
  red "More than one non-Windows partition found:"; printf '  %s\n' "${NEW[@]}"
  red "REFUSING to guess which one to format."
  red "Pass the one you want explicitly:  TARGET=/dev/nvme0n1pN $0"
  exit 1
fi

TARGET="${TARGET:-${NEW[0]}}"

# --- Guards -------------------------------------------------------------------
case "$TARGET" in
  ${DISK}p1|${DISK}p2|${DISK}p3|${DISK}p4|${DISK}p5)
    red "REFUSING: $TARGET is a Windows partition (MSR/ESP/C:/WinRE/MSI recovery)."; exit 1;;
esac

SZ=$(blockdev --getsize64 "$TARGET")
SZGB=$(( SZ / 1024 / 1024 / 1024 ))
if (( SZGB < 20 )); then
  red "REFUSING: $TARGET is only ${SZGB} GB. Expected the freed space from C: (>= 20 GB)."
  exit 1
fi

EXIST=$(blkid -o value -s TYPE "$TARGET" 2>/dev/null || true)
if [[ -n $EXIST ]]; then
  ylw "WARNING: $TARGET already contains a '$EXIST' filesystem."
  if [[ $EXIST == ntfs ]]; then
    red "REFUSING: that is NTFS - a Windows volume. Wrong target."; exit 1
  fi
fi

echo
ylw "About to run:  mkfs.ext4 $TARGET   (${SZGB} GB)"
lsblk -o NAME,SIZE,FSTYPE,PARTTYPENAME "$TARGET"
echo
read -rp "Type YES to format this partition: " ans
[[ $ans == YES ]] || { red "Aborted."; exit 1; }

mkfs.ext4 "$TARGET"
grn "Formatted $TARGET."
echo "$TARGET" > /tmp/arch-root-part
grn "Saved target to /tmp/arch-root-part. Next: ./02-install.sh"
