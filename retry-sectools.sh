#!/usr/bin/env bash
# Full sync+upgrade (fixes the 404 stale-db / partial-upgrade issue), then retry failed tools.
status() { echo "$1" > /root/retry.STATUS; }
status RUNNING

echo "=== full system upgrade (refresh DBs) ==="
pacman -Syyu --noconfirm >>/root/retry.log 2>&1

RETRY=(
  dnsrecon dnsenum theharvester sublist3r wafw00f netdiscover enum4linux recon-ng
  sqlmap wfuzz metasploit exploitdb set routersploit john hydra patator
  wireshark-qt ettercap mitmproxy radare2 rizin testdisk tor torsocks python-pwntools
)

OK=(); FAIL=()
for p in "${RETRY[@]}"; do
  if pacman -S --needed --noconfirm "$p" >>/root/retry.log 2>&1; then
    OK+=("$p"); echo "OK   $p"
  else
    FAIL+=("$p"); echo "FAIL $p"
  fi
done

echo "================"
echo "RETRY OK ${#OK[@]}: ${OK[*]}"
echo "STILL FAIL ${#FAIL[@]}: ${FAIL[*]}"
printf '%s\n' "${FAIL[@]}" > /root/retry.failed
df -h / | tail -1
status DONE
