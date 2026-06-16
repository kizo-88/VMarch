#!/usr/bin/env bash
echo "STATUS=$(cat /root/sectools.STATUS 2>/dev/null || echo none)"
echo "ACTIVE=$(systemctl is-active sectools 2>/dev/null)"
echo "OKcount=$(journalctl -u sectools --no-pager -o cat 2>/dev/null | grep -cE '^OK')"
echo "FAILS:"
journalctl -u sectools --no-pager -o cat 2>/dev/null | grep -E '^FAIL' | awk '{print $2}' | tr '\n' ' '
echo ""
df -h / | tail -1
