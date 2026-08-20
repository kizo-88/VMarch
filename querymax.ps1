# querymax.ps1 - READ ONLY. Asks diskpart how much C: can give up.
# "shrink querymax" only reports a number; it does not shrink anything.
# Run ELEVATED.  Do not click inside the console window (QuickEdit freezes it).

$ErrorActionPreference = 'Continue'
$out = Join-Path $PSScriptRoot 'querymax-out.txt'

$admin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $admin) { Write-Host "NOT ELEVATED - re-run as Administrator." -ForegroundColor Red; Read-Host "Enter to close"; exit 1 }

$script = @"
select volume C
shrink querymax
exit
"@

$tmp = Join-Path $env:TEMP 'querymax.dp'
Set-Content -Path $tmp -Value $script -Encoding ascii

Write-Host "Running diskpart shrink querymax (read-only)..." -ForegroundColor Cyan
$result = & diskpart /s $tmp
Remove-Item $tmp -ErrorAction SilentlyContinue

$result | Tee-Object -FilePath $out

# Pull the number out of whatever locale-formatted line diskpart returned.
$line = $result | Select-String -Pattern 'querymax|maximum|reclaim' -SimpleMatch:$false | Select-Object -First 1
if ($result -match '(\d[\d,\.]*)\s*(MB|GB)') {
    foreach ($l in $result) {
        if ($l -match '(\d[\d,\.]*)\s*MB') {
            $mb = [double](($matches[1]) -replace '[,\.]','')
            "" | Out-File -Append $out
            $msg = "MAX SHRINK: {0} MB  =  {1} GB" -f $mb, [math]::Round($mb/1024,2)
            Write-Host $msg -ForegroundColor Green
            $msg | Out-File -Append $out
            break
        }
    }
}

Write-Host "`nSaved to $out" -ForegroundColor Green
Read-Host "`nPress Enter to close"
