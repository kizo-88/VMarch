# Raw-write the Arch ISO to the USB SSD (equivalent to Rufus "DD Image mode" / dd).
# REFUSES anything that is not the 953 GB USB disk. Verifies by reading back and hashing.
$ErrorActionPreference = 'Stop'
$out = Join-Path $PSScriptRoot 'writeiso-out.txt'
$log = @()
function L($m) { $script:log += $m; Write-Host $m }

$ISO      = 'C:\.DEVELOPER\VM\archlinux.iso'
$DISKNUM  = 3
$EXPECTSHA = '4e82dced1c4fd3e498b22a853f8db2a4d262d32b97e7e07d97390d9e425ffe5e'

$src = $null; $dst = $null
try {
    if (-not (Test-Path $ISO)) { throw "ISO not found: $ISO" }
    $isoLen = (Get-Item $ISO).Length
    L ("ISO: {0}  ({1} bytes, {2} MB)" -f $ISO, $isoLen, [math]::Round($isoLen/1MB,0))

    $d = Get-Disk -Number $DISKNUM
    L ("Target: disk {0} '{1}' {2} {3} GB  IsBoot={4} IsSystem={5}" -f `
        $d.Number,$d.FriendlyName,$d.BusType,[math]::Round($d.Size/1GB,2),$d.IsBoot,$d.IsSystem)

    # ---- GUARDS: must be the USB SSD, must not be a system disk ----
    if ($d.BusType -ne 'USB')      { throw "disk $DISKNUM is $($d.BusType), expected USB. REFUSING." }
    if ($d.IsBoot -or $d.IsSystem) { throw "disk $DISKNUM is a boot/system disk. REFUSING." }
    if ($d.Size -lt 900GB)         { throw "disk $DISKNUM is only $([math]::Round($d.Size/1GB,1)) GB, expected ~953. REFUSING." }
    if ($d.Size -gt 1000GB)        { throw "disk $DISKNUM is $([math]::Round($d.Size/1GB,1)) GB, larger than expected. REFUSING." }
    foreach ($v in (Get-Partition -DiskNumber $DISKNUM -ErrorAction SilentlyContinue |
                    Get-Volume -ErrorAction SilentlyContinue)) {
        if ($v.Size) {
            $used = [math]::Round(($v.Size - $v.SizeRemaining)/1GB,2)
            L "  existing volume $($v.DriveLetter): used $used GB"
            if ($used -gt 1) { throw "volume $($v.DriveLetter): holds $used GB. REFUSING." }
        }
    }
    L "Guards passed."

    L "Clearing partition table..."
    Clear-Disk -Number $DISKNUM -RemoveData -RemoveOEM -Confirm:$false -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 2
    Set-Disk -Number $DISKNUM -IsOffline $true -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 2

    L "Writing image (this is the long part)..."
    $sw  = [Diagnostics.Stopwatch]::StartNew()
    $src = [System.IO.File]::OpenRead($ISO)
    $dst = New-Object System.IO.FileStream("\\.\PhysicalDrive$DISKNUM",
              [System.IO.FileMode]::Open, [System.IO.FileAccess]::Write, [System.IO.FileShare]::ReadWrite)

    $bufSize = 4MB
    $buf = New-Object byte[] $bufSize
    $total = 0
    while (($n = $src.Read($buf, 0, $bufSize)) -gt 0) {
        if ($n % 4096 -ne 0) {                  # pad the final chunk to a sector multiple
            $pad = 4096 - ($n % 4096)
            [Array]::Clear($buf, $n, $pad)
            $n += $pad
        }
        $dst.Write($buf, 0, $n)
        $total += $n
    }
    $dst.Flush(); $dst.Close(); $dst = $null
    $src.Close(); $src = $null
    $sw.Stop()
    L ("Wrote {0} MB in {1}s" -f [math]::Round($total/1MB,0), [math]::Round($sw.Elapsed.TotalSeconds,1))

    L "Verifying - reading back $([math]::Round($isoLen/1MB,0)) MB from the disk..."
    $rd = New-Object System.IO.FileStream("\\.\PhysicalDrive$DISKNUM",
              [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)
    $sha = [System.Security.Cryptography.SHA256]::Create()
    $rbuf = New-Object byte[] $bufSize
    $left = $isoLen
    while ($left -gt 0) {
        $want = [math]::Min($bufSize, $left)
        $wantAligned = if ($want % 4096 -ne 0) { $want + (4096 - ($want % 4096)) } else { $want }
        $got = $rd.Read($rbuf, 0, $wantAligned)
        if ($got -le 0) { break }
        $use = [math]::Min($want, $got)
        $sha.TransformBlock($rbuf, 0, $use, $null, 0) | Out-Null
        $left -= $use
    }
    $sha.TransformFinalBlock((New-Object byte[] 0), 0, 0) | Out-Null
    $rd.Close()
    $hash = ($sha.Hash | ForEach-Object { $_.ToString('x2') }) -join ''
    L "read-back sha256 : $hash"
    L "expected sha256  : $EXPECTSHA"
    if ($hash -eq $EXPECTSHA) { L "VERIFY OK - the ISO is on the disk byte-for-byte" }
    else                      { L "VERIFY FAILED - do not boot this" }

    Set-Disk -Number $DISKNUM -IsOffline $false -ErrorAction SilentlyContinue
    L "OK"
}
catch { L ("FAILED: " + $_.Exception.Message) }
finally {
    if ($dst) { try { $dst.Close() } catch {} }
    if ($src) { try { $src.Close() } catch {} }
    try { Set-Disk -Number $DISKNUM -IsOffline $false -ErrorAction SilentlyContinue } catch {}
}
$log | Out-File -FilePath $out -Encoding utf8

