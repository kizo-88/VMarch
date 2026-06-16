#!/usr/bin/env bash
# Install a broad curated cybersecurity toolkit from official + BlackArch repos.
# Loops per-package so a bad name skips instead of aborting the whole transaction.
status() { echo "$1" > /root/sectools.STATUS; }
status RUNNING

PKGS=(
  # --- Recon / Information Gathering ---
  nmap masscan rustscan dnsrecon dnsenum fierce theharvester sublist3r amass
  subfinder whatweb wafw00f sslscan netdiscover arp-scan enum4linux onesixtyone
  recon-ng dmitry fping nbtscan smbmap
  # --- Web Application ---
  sqlmap nikto wpscan gobuster ffuf feroxbuster dirb wfuzz commix xsstrike
  dalfox nuclei joomscan
  # --- Exploitation ---
  metasploit exploitdb set routersploit impacket responder evil-winrm netexec
  # --- Password Attacks ---
  john hashcat hydra medusa ncrack hashid hash-identifier crunch cewl patator
  # --- Wireless ---
  aircrack-ng wifite reaver bully pixiewps hcxtools hcxdumptool bettercap mdk4
  cowpatty macchanger
  # --- Sniffing / MITM ---
  wireshark-qt tcpdump ettercap dsniff mitmproxy yersinia
  # --- Reverse Engineering / Forensics ---
  radare2 rizin gdb binwalk foremost sleuthkit volatility3 perl-image-exiftool
  steghide stegseek testdisk
  # --- Wordlists ---
  seclists
  # --- Utilities ---
  proxychains-ng tor torsocks socat openbsd-netcat python-pwntools whois
  bind traceroute
)

OK=(); FAIL=()
for p in "${PKGS[@]}"; do
  if pacman -S --needed --noconfirm "$p" >>/root/sectools.log 2>&1; then
    OK+=("$p"); echo "OK   $p"
  else
    FAIL+=("$p"); echo "FAIL $p"
  fi
done

echo "============================="
echo "INSTALLED ${#OK[@]} : ${OK[*]}"
echo "SKIPPED   ${#FAIL[@]} : ${FAIL[*]}"
printf '%s\n' "${OK[@]}"  > /root/sectools.installed
printf '%s\n' "${FAIL[@]}" > /root/sectools.failed
df -h / | tail -1
status DONE
