#!/usr/bin/env bash
echo "=== PDF info ==="
python3 - <<'PY'
try:
    from pypdf import PdfReader
    r = PdfReader("/root/Cybersecurity-Toolkit-Tutorial.pdf")
    print("pages:", len(r.pages))
except Exception as e:
    import os
    print("pypdf missing; size:", os.path.getsize("/root/Cybersecurity-Toolkit-Tutorial.pdf"))
PY
echo "=== installed sec tools present on PATH ==="
TOOLS="nmap masscan rustscan dnsrecon fierce theharvester amass whatweb wafw00f sslscan netdiscover arp-scan enum4linux recon-ng nbtscan smbmap sqlmap nikto wpscan gobuster ffuf feroxbuster dirb wfuzz commix dalfox nuclei joomscan msfconsole searchsploit setoolkit impacket-secretsdump responder evil-winrm netexec john hashcat hydra medusa ncrack hashid crunch cewl patator aircrack-ng wifite reaver bully pixiewps bettercap mdk4 macchanger tshark tcpdump ettercap mitmproxy radare2 rizin gdb binwalk foremost vol exiftool steghide stegseek testdisk proxychains tor socat nc"
c=0
for t in $TOOLS; do command -v "$t" >/dev/null 2>&1 && c=$((c+1)); done
echo "tools_on_path=$c of $(echo $TOOLS | wc -w) checked"
echo "=== total explicitly-installed packages ==="
pacman -Qe | wc -l
echo "=== wordlists ==="
ls -d /usr/share/seclists 2>/dev/null && du -sh /usr/share/seclists 2>/dev/null | cut -f1
echo "=== disk ==="
df -h / | tail -1
