# READ ONLY - queries the shrink limit on C: and the shadow-copy list. Changes nothing.
$out = Join-Path $PSScriptRoot 'maxshrink-out.txt'
$lines = @()
$lines += "run: $(Get-Date -Format s)"
try {
  $p = Get-Partition -DriveLetter C
  $lines += ("Current size : {0} GB" -f [math]::Round($p.Size/1GB,2))
  $sw = [Diagnostics.Stopwatch]::StartNew()
  $s = Get-PartitionSupportedSize -DriveLetter C -ErrorAction Stop
  $sw.Stop()
  $lines += ("Minimum size : {0} GB" -f [math]::Round($s.SizeMin/1GB,2))
  $lines += ("MAX SHRINK   : {0} GB" -f [math]::Round(($p.Size - $s.SizeMin)/1GB,2))
  $lines += ("query took   : {0}s" -f [math]::Round($sw.Elapsed.TotalSeconds,1))
} catch {
  $lines += "QUERY FAILED: $($_.Exception.Message)"
}
$lines += "--- shadow copies ---"
$lines += (vssadmin list shadows 2>&1 | Select-String -Pattern 'Shadow Copy ID|Original Volume|creation time|No items found' | ForEach-Object { $_.ToString().Trim() })
$lines | Out-File -FilePath $out -Encoding utf8
