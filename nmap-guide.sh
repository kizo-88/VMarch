#!/bin/bash
# ============================================================
#  nmap-guide.sh — nmap quick-reference & helper for Arch VM
#  Run with:  bash nmap-guide.sh [option]
#
#  Options:
#    install   — install nmap via pacman
#    myip      — show your VM's IP address
#    ping      — ping-scan the local subnet
#    quick     — quick port scan on a target
#    full      — full port scan on a target
#    version   — service/version detection on a target
#    os        — OS detection on a target (needs root)
#    vuln      — run vuln NSE scripts on a target (needs root)
#    help      — show this menu
# ============================================================

RED='\033[0;31m'; GREEN='\033[0;32m'; CYAN='\033[0;36m'
YELLOW='\033[1;33m'; NC='\033[0m'

header() {
  echo -e "${CYAN}=================================================${NC}"
  echo -e "${CYAN}   nmap-guide.sh — Arch Linux VM nmap helper    ${NC}"
  echo -e "${CYAN}=================================================${NC}"
}

usage() {
  header
  echo -e ""
  echo -e "${YELLOW}Usage:${NC}  bash nmap-guide.sh [option] [target]"
  echo -e ""
  echo -e "${GREEN}  install${NC}           Install nmap via pacman"
  echo -e "${GREEN}  myip${NC}              Show this machine's IP addresses"
  echo -e "${GREEN}  ping   <subnet>${NC}   Ping-scan subnet (e.g. 192.168.1.0/24)"
  echo -e "${GREEN}  quick  <target>${NC}   Quick scan of common ports"
  echo -e "${GREEN}  full   <target>${NC}   Full scan of ALL 65535 ports"
  echo -e "${GREEN}  version <target>${NC}  Service & version detection"
  echo -e "${GREEN}  os     <target>${NC}   OS detection (requires root)"
  echo -e "${GREEN}  vuln   <target>${NC}   Vulnerability scan via NSE (requires root)"
  echo -e "${GREEN}  help${NC}              Show this menu"
  echo -e ""
  echo -e "Example: bash nmap-guide.sh quick 192.168.1.1"
}

need_target() {
  if [ -z "$2" ]; then
    echo -e "${RED}Error:${NC} Please provide a target. Example: bash nmap-guide.sh $1 192.168.1.1"
    exit 1
  fi
}

case "$1" in

  install)
    header
    echo -e "${YELLOW}Installing nmap...${NC}"
    pacman -Sy --noconfirm nmap
    echo -e "${GREEN}Done! Run: nmap --version${NC}"
    ;;

  myip)
    header
    echo -e "${YELLOW}Your IP addresses:${NC}"
    ip -4 addr show | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | grep -v 127.0.0.1
    ;;

  ping)
    need_target "$@"
    header
    echo -e "${YELLOW}Ping-scanning: $2${NC}"
    echo -e "${CYAN}Command: nmap -sn $2${NC}\n"
    nmap -sn "$2"
    ;;

  quick)
    need_target "$@"
    header
    echo -e "${YELLOW}Quick scan on: $2${NC}"
    echo -e "${CYAN}Command: nmap -T4 -F $2${NC}\n"
    nmap -T4 -F "$2"
    ;;

  full)
    need_target "$@"
    header
    echo -e "${YELLOW}Full port scan on: $2 (this may take a while...)${NC}"
    echo -e "${CYAN}Command: nmap -T4 -p- $2${NC}\n"
    nmap -T4 -p- "$2"
    ;;

  version)
    need_target "$@"
    header
    echo -e "${YELLOW}Service/version detection on: $2${NC}"
    echo -e "${CYAN}Command: nmap -sV -sC $2${NC}\n"
    nmap -sV -sC "$2"
    ;;

  os)
    need_target "$@"
    header
    echo -e "${YELLOW}OS detection on: $2 (requires root)${NC}"
    echo -e "${CYAN}Command: nmap -O $2${NC}\n"
    nmap -O "$2"
    ;;

  vuln)
    need_target "$@"
    header
    echo -e "${YELLOW}Vulnerability scan on: $2 (requires root)${NC}"
    echo -e "${CYAN}Command: nmap --script vuln $2${NC}\n"
    nmap --script vuln "$2"
    ;;

  help|"")
    usage
    ;;

  *)
    echo -e "${RED}Unknown option: $1${NC}"
    usage
    exit 1
    ;;

esac
