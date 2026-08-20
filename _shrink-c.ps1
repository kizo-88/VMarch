# Step 1 - shrink C: by 120 GB, leaving the freed space UNALLOCATED.
# Run ELEVATED. Verifies before and after; refuses if anything looks wrong.
$ErrorActionPreference = 'Stop'
$out = Join-Path $PSScriptRoot 'shrink-out.txt'
$log = @()
function L($m) { $script:log += $m; Write-Host $m }

try {
    $p = Get-Partition -DriveLetter C
    if ($p.DiskNumber -ne 1)  { throw "C: is on disk $($p.DiskNumber), expected disk 1. STOP." }
    if ($p.PartitionNumber -ne 3) { throw "C: is partition $($p.PartitionNumber), expected p3. STOP." }

    $shrinkBy = 120GB
    $target   = $p.Size - $shrinkBy
    L ("Current C: size : {0} GB" -f [math]::Round($p.Size/1GB,3))
    L ("Shrink by       : {0} GB" -f [math]::Round($shrinkBy/1GB,3))
    L ("New C: size     : {0} GB" -f [math]::Round($target/1GB,3))

    $d = Get-Disk -Number 1
    $usedBefore = (Get-Partition -DiskNumber 1 | Measure-Object -Property Size -Sum).Sum
    L ("Unallocated before: {0} GB" -f [math]::Round(($d.Size - $usedBefore)/1GB,2))

    L "Resizing..."
    Resize-Partition -DriveLetter C -Size $target

    Start-Sleep -Seconds 3
    Update-HostStorageCache
    $p2 = Get-Partition -DriveLetter C
    $d2 = Get-Disk -Number 1
    $usedAfter = (Get-Partition -DiskNumber 1 | Measure-Object -Property Size -Sum).Sum
    L ("RESULT C: size    : {0} GB" -f [math]::Round($p2.Size/1GB,3))
    L ("RESULT Unallocated: {0} GB" -f [math]::Round(($d2.Size - $usedAfter)/1GB,2))
    L "--- disk 1 layout now ---"
    $log += (Get-Partition -DiskNumber 1 | Format-Table PartitionNumber,DriveLetter,@{n='SizeGB';e={[math]::Round($_.Size/1GB,3)}},@{n='OffsetGB';e={[math]::Round($_.Offset/1GB,2)}},Type -Auto | Out-String)
    L "OK"
}
catch { L ("FAILED: " + $_.Exception.Message) }

$log | Out-File -FilePath $out -Encoding utf8
