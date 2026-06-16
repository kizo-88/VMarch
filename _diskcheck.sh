#!/usr/bin/env bash
echo "--- disk ---"
df -h / | tail -1
echo "--- free space (GB) ---"
df -BG / | tail -1 | awk '{print "used="$3" avail="$4}'
echo "--- already-installed sec tools ---"
for t in nmap wireshark-cli tcpdump john hashcat hydra sqlmap nikto aircrack-ng metasploit; do
  pacman -Q "$t" >/dev/null 2>&1 && echo "have $t"
done
echo "--- multilib enabled? ---"
grep -q '^\[multilib\]' /etc/pacman.conf && echo multilib_on || echo multilib_off
echo "--- blackarch repo? ---"
grep -q '^\[blackarch\]' /etc/pacman.conf && echo blackarch_on || echo blackarch_off
