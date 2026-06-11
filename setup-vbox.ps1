# Configure / repair the Arch Linux VM in VirtualBox (Oracle).
# The disk arch.vdi is a BIOS/MBR install with GRUB, so the VM MUST use BIOS
# firmware (NOT EFI) or it will not boot. This script is safe to re-run: it
# recreates the registration to match the existing disk without reformatting it.
$VBoxPath = "C:\Program Files\Oracle\VirtualBox\VBoxManage.exe"
$VmName   = "ArchLinux-VM"
$DiskPath = "C:\.Developer\VM\arch.vdi"

if (-not (Test-Path $VBoxPath)) {
    Write-Error "VirtualBox not found at: $VBoxPath. Install it first (winget install Oracle.VirtualBox)."
    exit 1
}
if (-not (Test-Path $DiskPath)) {
    Write-Error "Disk image not found at: $DiskPath"
    exit 1
}

# Remove any prior registration (keep the disk file - do not delete it).
$existing = & $VBoxPath list vms
if ($existing -match [regex]::Escape($VmName)) {
    Write-Output "Unregistering existing '$VmName' (disk file is preserved)..."
    & $VBoxPath unregistervm $VmName --delete 2>$null
}

Write-Output "Creating VM: $VmName"
& $VBoxPath createvm --name $VmName --ostype "ArchLinux_64" --register

# BIOS firmware (matches the MBR/GRUB install). EFI would NOT boot this disk.
& $VBoxPath modifyvm $VmName --memory 2048 --cpus 2 --vram 128 `
    --firmware bios --graphicscontroller vmsvga --mouse usbtablet --nic1 nat

# SATA controller + attach the existing disk (do NOT createmedium - it already exists).
& $VBoxPath storagectl $VmName --name "SATA Controller" --add sata --controller IntelAhci
& $VBoxPath storageattach $VmName --storagectl "SATA Controller" --port 0 --device 0 --type hdd --medium $DiskPath

# Boot order: disk first.
& $VBoxPath modifyvm $VmName --boot1 disk --boot2 none --boot3 none --boot4 none

Write-Output ""
Write-Output "Done. '$VmName' is configured for BIOS boot from the installed disk."
Write-Output "Start it with:  & '$VBoxPath' startvm '$VmName' --type gui"
