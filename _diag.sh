#!/usr/bin/env bash
echo "===== /etc/pam.d/lightdm-autologin ====="
cat /etc/pam.d/lightdm-autologin
echo "===== autologin group ====="
getent group autologin
echo "===== tail lightdm.conf ====="
tail -n 15 /etc/lightdm/lightdm.conf
echo "===== greeter/seat log (autologin lines) ====="
journalctl -u lightdm --no-pager -o cat 2>/dev/null | tail -n 25
