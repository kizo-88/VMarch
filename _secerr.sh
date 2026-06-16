#!/usr/bin/env bash
for p in john metasploit sqlmap radare2 wireshark-qt tor theharvester; do
  echo "===== $p ====="
  pacman -S --needed --noconfirm "$p" 2>&1 | grep -iE 'error|conflict|could not|satisfy|breaks|unresolvable|require' | head -4
done
