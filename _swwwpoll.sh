#!/usr/bin/env bash
echo "STATUS=$(cat /root/swww-fix.STATUS 2>/dev/null || echo none)"
echo "ACTIVE=$(systemctl is-active swwwfix 2>/dev/null)"
echo -n "swww: "; command -v swww || echo no
echo -n "swww-daemon: "; command -v swww-daemon || echo no
echo "--- journal tail ---"
journalctl -u swwwfix --no-pager -o cat 2>/dev/null | tail -n 6
