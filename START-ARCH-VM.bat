@echo off
REM Double-click this file to start the Arch Linux VM in VirtualBox.
title Starting Arch Linux VM...
echo Launching Arch Linux in VirtualBox...
"C:\Program Files\Oracle\VirtualBox\VBoxManage.exe" startvm "ArchLinux-VM" --type gui
if errorlevel 1 (
    echo.
    echo Could not start the VM. Make sure VirtualBox is installed.
    pause
)
