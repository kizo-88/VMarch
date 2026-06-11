$Url = "https://geo.mirror.pkgbuild.com/iso/latest/archlinux-x86_64.iso"
$OutputPath = "c:\.Developer\VM\archlinux.iso"

Write-Output "Starting download of Arch Linux ISO..."
try {
    Start-BitsTransfer -Source $Url -Destination $OutputPath -ErrorAction Stop
    Write-Output "Download completed successfully using BITS."
} catch {
    Write-Output "BITS download failed or not available. Falling back to Invoke-WebRequest..."
    try {
        Invoke-WebRequest -Uri $Url -OutFile $OutputPath
        Write-Output "Download completed successfully using Invoke-WebRequest."
    } catch {
        Write-Error "Failed to download Arch Linux ISO: $_"
    }
}
