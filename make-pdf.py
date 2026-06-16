#!/usr/bin/env python3
"""Generate the Cybersecurity Toolkit tutorial PDF for the Arch VM."""
import os
from reportlab.lib.pagesizes import A4
from reportlab.lib.units import mm
from reportlab.lib import colors
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.platypus import (SimpleDocTemplate, Paragraph, Spacer, PageBreak,
                                Table, TableStyle, HRFlowable)
from reportlab.lib.enums import TA_CENTER

OUT = "/root/Cybersecurity-Toolkit-Tutorial.pdf"

# ---- palette ----
BG   = colors.HexColor("#0d1117")
ACC  = colors.HexColor("#2f81f7")
ACC2 = colors.HexColor("#3fb950")
CODE_BG = colors.HexColor("#161b22")
GREY = colors.HexColor("#57606a")

styles = getSampleStyleSheet()
H1 = ParagraphStyle('H1', parent=styles['Heading1'], fontSize=18, textColor=ACC,
                    spaceBefore=14, spaceAfter=6)
H2 = ParagraphStyle('H2', parent=styles['Heading2'], fontSize=13, textColor=ACC2,
                    spaceBefore=10, spaceAfter=4)
BODY = ParagraphStyle('Body', parent=styles['Normal'], fontSize=10, leading=14,
                      spaceAfter=5)
NOTE = ParagraphStyle('Note', parent=BODY, textColor=GREY, fontSize=9)
CODE = ParagraphStyle('Code', parent=styles['Code'], fontName='Courier', fontSize=9,
                      leading=12, textColor=colors.whitesmoke, backColor=CODE_BG,
                      borderPadding=6, leftIndent=4, spaceBefore=2, spaceAfter=8)
TITLE = ParagraphStyle('Title', parent=styles['Title'], fontSize=30, textColor=ACC,
                       spaceAfter=4)
SUB = ParagraphStyle('Sub', parent=styles['Normal'], fontSize=12, textColor=GREY,
                     alignment=TA_CENTER)

def code(txt):
    return Paragraph(txt.replace('&','&amp;').replace('<','&lt;').replace('>','&gt;')
                     .replace('\n','<br/>'), CODE)

story = []

# ---------- cover ----------
story += [Spacer(1, 60*mm),
          Paragraph("Cybersecurity Toolkit", TITLE),
          Paragraph("Hands-on Tutorial for the Arch Linux VM", SUB),
          Spacer(1, 8*mm),
          HRFlowable(width="60%", color=ACC, thickness=2),
          Spacer(1, 8*mm),
          Paragraph("BlackArch tools on Arch Linux &bull; Hyprland desktop", SUB),
          Paragraph("Login: arch / arch", SUB),
          PageBreak()]

# ---------- legal ----------
story += [Paragraph("0. Read This First — Legal &amp; Ethics", H1),
  Paragraph("These tools are for <b>authorized testing and learning only</b>. Only scan, probe, "
   "or attack systems you <b>own</b> or have <b>explicit written permission</b> to test. "
   "Unauthorized access or scanning is illegal in most countries (e.g. the U.S. CFAA, the UK "
   "Computer Misuse Act).", BODY),
  Paragraph("Build a safe lab instead of touching real targets:", BODY),
  Paragraph("&bull; Practice VMs: Metasploitable2/3, OWASP Juice Shop, DVWA, VulnHub images.<br/>"
            "&bull; Online labs: TryHackMe, Hack The Box, PortSwigger Web Security Academy.<br/>"
            "&bull; Keep targets on an isolated host-only network.", BODY),
  Spacer(1,4*mm)]

# ---------- how the toolkit is organized ----------
story += [Paragraph("1. How This VM Is Set Up", H1),
  Paragraph("The BlackArch repository (~5,000 security packages) and multilib are enabled on top "
   "of Arch. A broad toolkit is already installed. To add more tools later:", BODY),
  code("# search the security repo\npacman -Ss <keyword>\n\n"
       "# install a tool\nsudo pacman -S <tool>\n\n"
       "# install a whole BlackArch category (large!)\n"
       "sudo pacman -S blackarch-scanner   # or -webapp, -cracker, -wireless ..."),
  Paragraph("Wordlists live in <font face='Courier'>/usr/share/seclists</font> and "
            "<font face='Courier'>/usr/share/wordlists</font> (rockyou.txt is the classic).", NOTE)]

# ---------- categories ----------
sections = [
 ("2. Reconnaissance &amp; Information Gathering",
  "Map what exists before touching it: hosts, ports, DNS, subdomains, services.",
  [("nmap", "The core network/port scanner.",
    "nmap -sV -sC -oN scan.txt 192.168.56.0/24   # service+script scan a subnet\n"
    "nmap -p- --min-rate 5000 10.0.0.5            # all 65535 ports, fast"),
   ("masscan / rustscan", "Internet-speed port sweeps, then hand off to nmap.",
    "rustscan -a 10.0.0.5 -- -sV\n"
    "masscan 10.0.0.0/24 -p1-65535 --rate 10000"),
   ("dnsrecon / fierce / amass", "Enumerate DNS records and subdomains.",
    "dnsrecon -d example.com\namass enum -d example.com"),
   ("whatweb / wafw00f", "Fingerprint web tech and detect WAFs.",
    "whatweb https://example.com\nwafw00f https://example.com"),
   ("enum4linux / netexec", "Enumerate SMB/Windows shares, users, policies.",
    "enum4linux -a 10.0.0.10\nnetexec smb 10.0.0.0/24 -u user -p pass --shares")]),

 ("3. Web Application Testing",
  "Find and exploit common web flaws: injection, XSS, hidden content.",
  [("sqlmap", "Automated SQL injection detection &amp; exploitation.",
    "sqlmap -u 'http://site/item?id=1' --batch --dbs\n"
    "sqlmap -u '...' --batch --dump -D appdb -T users"),
   ("gobuster / ffuf / feroxbuster", "Brute-force directories, files, vhosts.",
    "gobuster dir -u http://site -w /usr/share/seclists/Discovery/Web-Content/common.txt\n"
    "ffuf -u http://site/FUZZ -w wordlist.txt"),
   ("nikto", "Quick web server vulnerability scan.",
    "nikto -h http://site"),
   ("wpscan", "WordPress-specific scanner.",
    "wpscan --url http://site --enumerate u,vp")]),

 ("4. Exploitation",
  "Turn a known weakness into access — in your lab only.",
  [("Metasploit Framework", "The standard exploitation framework.",
    "msfconsole\nsearch type:exploit smb\nuse exploit/...\nset RHOSTS 10.0.0.5\nrun"),
   ("searchsploit (exploitdb)", "Offline Exploit-DB search.",
    "searchsploit apache 2.4\nsearchsploit -m 50383   # copy an exploit locally"),
   ("impacket / netexec", "Windows/AD protocol toolkit &amp; lateral movement.",
    "impacket-secretsdump domain/user:pass@10.0.0.10\n"
    "netexec smb 10.0.0.10 -u u -p p -x whoami"),
   ("evil-winrm", "Interactive shell over WinRM.",
    "evil-winrm -i 10.0.0.10 -u admin -p pass")]),

 ("5. Password Attacks",
  "Crack hashes offline or brute services online (lab only).",
  [("hashcat", "GPU-accelerated hash cracking.",
    "hashcat -m 0 hashes.txt /usr/share/seclists/Passwords/rockyou.txt   # MD5\n"
    "hashcat -m 1000 ntlm.txt rockyou.txt   # NTLM"),
   ("hydra / medusa / ncrack", "Online brute force of network logins.",
    "hydra -l admin -P rockyou.txt ssh://10.0.0.5\n"
    "hydra -L users.txt -P pass.txt ftp://10.0.0.5"),
   ("hashid / hash-identifier", "Identify an unknown hash type.",
    "hashid '5f4dcc3b5aa765d61d8327deb882cf99'"),
   ("crunch / cewl", "Generate custom wordlists.",
    "crunch 8 8 -o list.txt\ncewl http://site -w site-words.txt")]),

 ("6. Wireless",
  "Audit Wi-Fi (needs a USB adapter passed into the VM that supports monitor mode).",
  [("aircrack-ng suite", "Capture handshakes and crack WPA.",
    "airmon-ng start wlan0\nairodump-ng wlan0mon\n"
    "aircrack-ng -w rockyou.txt capture.cap"),
   ("wifite", "Automated wireless auditing wrapper.",
    "wifite"),
   ("bettercap", "Swiss-army network/MITM/wireless tool.",
    "bettercap -iface wlan0")]),

 ("7. Sniffing &amp; MITM",
  "Inspect and manipulate traffic on a network you control.",
  [("Wireshark / tcpdump", "Capture and analyze packets.",
    "tcpdump -i eth0 -w cap.pcap\nwireshark cap.pcap"),
   ("ettercap / bettercap", "ARP spoofing and man-in-the-middle.",
    "ettercap -T -M arp /10.0.0.5// /10.0.0.1//"),
   ("mitmproxy", "Intercept and edit HTTP(S).",
    "mitmproxy")]),

 ("8. Reverse Engineering &amp; Forensics",
  "Analyze binaries, carve files, inspect memory and disks.",
  [("radare2 / rizin", "Disassemble and debug binaries.",
    "r2 -A ./binary\n# inside: aaa; afl; pdf @main"),
   ("binwalk / foremost", "Analyze firmware, carve embedded files.",
    "binwalk -e firmware.bin\nforemost -i disk.img -o out/"),
   ("volatility3", "Memory-image forensics.",
    "vol -f mem.raw windows.pslist"),
   ("steghide / stegseek", "Hide/recover data in images (stego).",
    "steghide extract -sf image.jpg\nstegseek image.jpg rockyou.txt"),
   ("exiftool", "Read/strip file metadata.",
    "exiftool photo.jpg")]),

 ("9. Anonymity &amp; Utilities",
  "Route tools through proxies/Tor and pivot.",
  [("proxychains-ng + tor", "Route any tool through Tor/proxies.",
    "sudo systemctl start tor\nproxychains nmap -sT 10.0.0.5"),
   ("socat / netcat", "Swiss-army networking, shells, port relays.",
    "nc -lvnp 4444            # listener\n"
    "socat TCP-LISTEN:4444,fork TCP:10.0.0.5:80")]),
]

for title, intro, tools in sections:
    story.append(Paragraph(title, H1))
    story.append(Paragraph(intro, BODY))
    for name, desc, ex in tools:
        story.append(Paragraph(name, H2))
        story.append(Paragraph(desc, BODY))
        story.append(code(ex))
    story.append(Spacer(1, 2*mm))

# ---------- workflow ----------
story += [PageBreak(),
  Paragraph("10. A Typical Engagement Flow", H1),
  Paragraph("1. <b>Recon</b> — discover hosts/ports/services (nmap, masscan).<br/>"
            "2. <b>Enumerate</b> — dig into each service (enum4linux, whatweb, gobuster).<br/>"
            "3. <b>Find weaknesses</b> — version/CVE lookup (searchsploit, nuclei, nikto).<br/>"
            "4. <b>Exploit</b> — gain access in your lab (metasploit, sqlmap).<br/>"
            "5. <b>Post-exploit</b> — loot/pivot (impacket, netexec, mimikatz-style).<br/>"
            "6. <b>Crack</b> — offline hash cracking (hashcat, john).<br/>"
            "7. <b>Report</b> — document findings and remediation.", BODY),
  Spacer(1,4*mm),
  Paragraph("Learn More", H2),
  Paragraph("&bull; PortSwigger Web Security Academy (free)<br/>"
            "&bull; TryHackMe / Hack The Box<br/>"
            "&bull; OWASP Testing Guide<br/>"
            "&bull; BlackArch tool list: blackarch.org/tools.html", BODY),
  Spacer(1,8*mm),
  HRFlowable(width="100%", color=GREY, thickness=0.5),
  Paragraph("Generated for the ArchLinux-VM lab. Use responsibly and legally.", NOTE)]

doc = SimpleDocTemplate(OUT, pagesize=A4, topMargin=18*mm, bottomMargin=16*mm,
                        leftMargin=18*mm, rightMargin=18*mm,
                        title="Cybersecurity Toolkit Tutorial")
doc.build(story)
print("PDF_WRITTEN", OUT, os.path.getsize(OUT), "bytes")
