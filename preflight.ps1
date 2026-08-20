# preflight.ps1 - READ ONLY. Changes nothing. Run in an ELEVATED PowerShell.
# Reports the three things a non-elevated shell cannot see, plus the disk layout.

$ErrorActionPreference = 'Continue'
$log = Join-Path $PSScriptRoot 'preflight-out.txt'
try { Start-Transcript -Path $log -Force | Out-Null } catch {}

Write-Host "`n=== ELEVATED ===" -ForegroundColor Cyan
$admin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
Write-Host "Administrator: $admin"
if (-not $admin) { Write-Host "NOT ELEVATED - re-run as Administrator." -ForegroundColor Red; exit 1 }

Write-Host "`n=== SECURE BOOT ===" -ForegroundColor Cyan
try { Write-Host ("SecureBootEnabled = " + (Confirm-SecureBootUEFI)) } catch { Write-Host "query failed: $($_.Exception.Message)" }

Write-Host "`n=== BITLOCKER ===" -ForegroundColor Cyan
try { Get-BitLockerVolume | Format-Table MountPoint,VolumeStatus,ProtectionStatus,EncryptionPercentage,KeyProtector -Auto } catch { Write-Host "query failed: $($_.Exception.Message)" }

Write-Host "`n=== FAST STARTUP (want 0) ===" -ForegroundColor Cyan
(Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power' -Name HiberbootEnabled -ErrorAction SilentlyContinue).HiberbootEnabled

Write-Host "`n=== HIBERFIL ===" -ForegroundColor Cyan
if (Test-Path C:\hiberfil.sys) { "hiberfil.sys PRESENT (run: powercfg /h off)" } else { "absent - good" }

Write-Host "`n=== SHADOW COPIES ===" -ForegroundColor Cyan
vssadmin list shadows 2>&1 | Select-String -Pattern 'Shadow Copy ID|No items found' | Select-Object -First 10

Write-Host "`n=== DISK 1 LAYOUT ===" -ForegroundColor Cyan
Get-Partition -DiskNumber 1 | Format-Table PartitionNumber,DriveLetter,@{n='SizeGB';e={[math]::Round($_.Size/1GB,3)}},@{n='OffsetGB';e={[math]::Round($_.Offset/1GB,2)}},Type -Auto

Write-Host "`n=== HOW MUCH C: CAN GIVE UP ===" -ForegroundColor Cyan
# Get-PartitionSupportedSize takes ~6 MINUTES on this 912 GB volume. Called inline it gets
# torn down mid-pipeline ("The pipeline has been stopped") and reports nothing, which is how
# the bogus 54.1 GB figure ended up in DUALBOOT.md. Run it in a job and actually wait.
$p = Get-Partition -DriveLetter C
"Current size : {0} GB" -f [math]::Round($p.Size/1GB,2)
Write-Host "Querying the shrink limit - this takes about 6 minutes. Do not close this window." -ForegroundColor Yellow
$job = Start-Job { Get-PartitionSupportedSize -DriveLetter C }
if (Wait-Job $job -Timeout 900) {
    $s = Receive-Job $job
    if ($s) {
        "Minimum size : {0} GB" -f [math]::Round($s.SizeMin/1GB,2)
        "MAX SHRINK   : {0} GB" -f [math]::Round(($p.Size - $s.SizeMin)/1GB,2)
    } else {
        Write-Host "query returned nothing - run _maxshrink.ps1 instead" -ForegroundColor Red
    }
} else {
    Write-Host "still running after 15 min - run _maxshrink.ps1 instead" -ForegroundColor Red
}
Remove-Job $job -Force -ErrorAction SilentlyContinue

Write-Host "`n=== UNALLOCATED SPACE ON DISK 1 ===" -ForegroundColor Cyan
$d = Get-Disk -Number 1
$used = (Get-Partition -DiskNumber 1 | Measure-Object -Property Size -Sum).Sum
"Unallocated: {0} GB" -f [math]::Round(($d.Size - $used)/1GB,2)

Write-Host "`n=== USB STICKS ATTACHED ===" -ForegroundColor Cyan
$usb = Get-Disk | Where-Object { $_.BusType -eq 'USB' }
if ($usb) { $usb | Format-Table Number,FriendlyName,@{n='SizeGB';e={[math]::Round($_.Size/1GB,1)}} -Auto } else { "none plugged in" }

Write-Host "`nDone. Nothing was modified.`n" -ForegroundColor Green
try { Stop-Transcript | Out-Null } catch {}
