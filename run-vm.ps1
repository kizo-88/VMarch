# Run the installed Arch Linux VM with QEMU (boots from the virtual disk)
$QemuPath = "C:\.Developer\VM\qemu\qemu-system-x86_64.exe"
$DiskPath = "C:\.Developer\VM\arch.vdi"

if (-not (Test-Path $QemuPath)) { Write-Error "QEMU not found at $QemuPath"; exit 1 }
if (-not (Test-Path $DiskPath)) { Write-Error "Disk not found at $DiskPath"; exit 1 }

Write-Output "Launching QEMU - Arch Linux (BIOS boot from disk)"
Write-Output "Memory: 2GB | CPUs: 2 | Accel: WHPX with TCG fallback"
Write-Output "(The disk is a BIOS/MBR install with GRUB - do NOT add UEFI firmware.)"

# Explicit format=vdi avoids format-probe warnings. -boot c boots the hard disk.
# Run both VirtualBox and QEMU against this disk one at a time only - never together.
$qemuArgs = @(
    "-m", "2048",
    "-smp", "2",
    "-drive", "file=$DiskPath,format=vdi",
    "-boot", "c",
    "-net", "nic", "-net", "user",
    "-accel", "whpx", "-accel", "tcg"
)

Start-Process -FilePath $QemuPath -ArgumentList $qemuArgs
