# nmap Tutorial for Arch Linux VM

A practical guide to using **nmap** inside your Arch Linux VM — from installation to real-world scanning techniques.

---

## 1. Install nmap

Run this inside your Arch VM terminal:

```bash
sudo pacman -Sy --noconfirm nmap
nmap --version
```

---

## 2. Find Your Own IP

```bash
ip -4 addr show
```

Or use the helper script:

```bash
bash nmap-guide.sh myip
```

---

## 3. Common nmap Commands

### Ping Scan — Find live hosts on your network
```bash
nmap -sn 192.168.1.0/24
```
> Replaces `ping` to discover all active devices on the subnet. No port scanning.

---

### Quick Scan — Fast scan of top 100 ports
```bash
nmap -T4 -F 192.168.1.1
```
> `-T4` = aggressive speed. `-F` = fast mode (top 100 ports only).

---

### Full Port Scan — Scan ALL 65535 ports
```bash
nmap -T4 -p- 192.168.1.1
```
> Takes longer but finds every open port.

---

### Service & Version Detection
```bash
nmap -sV -sC 192.168.1.1
```
> `-sV` detects service versions. `-sC` runs default NSE scripts.

---

### OS Detection (requires root)
```bash
sudo nmap -O 192.168.1.1
```
> Tries to guess the operating system of the target.

---

### Vulnerability Scan (requires root)
```bash
sudo nmap --script vuln 192.168.1.1
```
> Runs built-in vulnerability detection scripts (NSE).

---

### Scan Multiple Targets
```bash
nmap 192.168.1.1 192.168.1.2 192.168.1.3
nmap 192.168.1.1-10
nmap 192.168.1.0/24
```

---

### Save Output to a File
```bash
nmap -oN output.txt 192.168.1.1      # Normal text
nmap -oX output.xml 192.168.1.1      # XML format
nmap -oG output.gnmap 192.168.1.1    # Grepable format
```

---

## 4. Speed Reference (`-T` Timing)

| Flag | Name       | Use Case                      |
|------|------------|-------------------------------|
| `-T0` | Paranoid  | IDS evasion (very slow)       |
| `-T1` | Sneaky    | IDS evasion (slow)            |
| `-T2` | Polite    | Low bandwidth use             |
| `-T3` | Normal    | Default speed                 |
| `-T4` | Aggressive | Faster, needs good network   |
| `-T5` | Insane    | Fastest, may miss results     |

---

## 5. Using the Helper Script

A helper script `nmap-guide.sh` is included in this repo. Copy it into your Arch VM and run it:

```bash
# Make it executable
chmod +x nmap-guide.sh

# Show available options
bash nmap-guide.sh help

# Install nmap
bash nmap-guide.sh install

# Discover hosts on your subnet
bash nmap-guide.sh ping 192.168.1.0/24

# Quick port scan
bash nmap-guide.sh quick 192.168.1.1

# Full port scan
bash nmap-guide.sh full 192.168.1.1

# Service detection
bash nmap-guide.sh version 192.168.1.1

# OS detection (run as root)
sudo bash nmap-guide.sh os 192.168.1.1

# Vulnerability scan (run as root)
sudo bash nmap-guide.sh vuln 192.168.1.1
```

---

## 6. Copy Script into Your VM

Since the script lives on your Windows host, copy it into the VM using QEMU's built-in clipboard, or re-create it with this command inside the VM:

```bash
curl -o nmap-guide.sh https://raw.githubusercontent.com/kizo-88/VMarch/main/nmap-guide.sh
chmod +x nmap-guide.sh
```

---

> ⚠️ **Legal Notice:** Only scan networks and devices you own or have explicit permission to test. Unauthorized scanning is illegal in most countries.
