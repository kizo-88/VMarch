# Free the Samsung USB SSD (physical DeviceId 3) from Storage Spaces so Rufus can see it.
# Targets BY OBJECT, never by FriendlyName - two pools are both called "Storage pool"
# and one of them backs D: on the internal HDD.
$ErrorActionPreference = 'Stop'
$out = Join-Path $PSScriptRoot 'unpool-out.txt'
$log = @()
function L($m) { $script:log += $m; Write-Host $m }

try {
    $TARGET_PD = 3   # the USB SSD

    $pd = Get-PhysicalDisk | Where-Object DeviceId -eq $TARGET_PD
    if (-not $pd)                 { throw "physical disk $TARGET_PD not found" }
    if ($pd.BusType -ne 'USB')    { throw "physical disk $TARGET_PD is $($pd.BusType), expected USB. STOP." }
    L "Target physical disk: $($pd.DeviceId) '$($pd.FriendlyName)' $($pd.BusType) $([math]::Round($pd.Size/1GB,1)) GB"

    # Find the pool that actually contains THIS disk.
    $pool = Get-StoragePool | Where-Object { -not $_.IsPrimordial } |
            Where-Object { (Get-PhysicalDisk -StoragePool $_).DeviceId -contains $TARGET_PD }
    if (-not $pool)               { throw "no pool contains physical disk $TARGET_PD - nothing to do" }
    if ($pool.Count -gt 1)        { throw "more than one pool claims disk $TARGET_PD. STOP." }

    # GUARD: the pool must contain ONLY disk 3. Never touch the internal HDD or the NVMe.
    $members = (Get-PhysicalDisk -StoragePool $pool).DeviceId
    L "Pool '$($pool.FriendlyName)' members: $($members -join ', ')"
    foreach ($m in $members) { if ($m -ne $TARGET_PD) { throw "pool also contains physical disk $m. REFUSING." } }

    # GUARD: no virtual disk in this pool may hold real data.
    foreach ($vd in (Get-VirtualDisk -StoragePool $pool)) {
        L "  virtual disk '$($vd.FriendlyName)' $([math]::Round($vd.Size/1GB,1)) GB"
        foreach ($p in (Get-Disk -VirtualDisk $vd | Get-Partition -ErrorAction SilentlyContinue)) {
            $v = Get-Volume -Partition $p -ErrorAction SilentlyContinue
            if ($v -and $v.Size) {
                $usedGB = [math]::Round(($v.Size - $v.SizeRemaining)/1GB,2)
                L "    volume $($v.DriveLetter): used $usedGB GB"
                if ($usedGB -gt 1) { throw "volume $($v.DriveLetter): holds $usedGB GB of data. REFUSING." }
            }
        }
    }

    L "Guards passed. Removing virtual disks, then the pool..."
    foreach ($vd in (Get-VirtualDisk -StoragePool $pool)) {
        L "  removing virtual disk '$($vd.FriendlyName)'"
        $vd | Remove-VirtualDisk -Confirm:$false
    }
    $pool | Remove-StoragePool -Confirm:$false
    L "Pool removed."

    Start-Sleep -Seconds 3
    Update-HostStorageCache
    Start-Sleep -Seconds 2
    $pd2 = Get-PhysicalDisk | Where-Object DeviceId -eq $TARGET_PD
    L "RESULT physical: '$($pd2.FriendlyName)' CanPool=$($pd2.CanPool)"
    $d = Get-Disk | Where-Object { $_.BusType -eq 'USB' }
    if ($d) { $log += ($d | Format-Table Number,FriendlyName,BusType,PartitionStyle,@{n='SizeGB';e={[math]::Round($_.Size/1GB,2)}} -Auto | Out-String) }
    else    { L "no USB disk enumerated yet - may need a replug" }
    L "--- D: must still be here ---"
    $log += (Get-Volume -DriveLetter D | Format-Table DriveLetter,FileSystemLabel,@{n='SizeGB';e={[math]::Round($_.Size/1GB,1)}},@{n='FreeGB';e={[math]::Round($_.SizeRemaining/1GB,1)}} -Auto | Out-String)
    L "OK"
}
catch { L ("FAILED: " + $_.Exception.Message) }
$log | Out-File -FilePath $out -Encoding utf8
