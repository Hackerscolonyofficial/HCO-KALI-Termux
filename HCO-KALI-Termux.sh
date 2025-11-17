#!/usr/bin/env bash
# HCO-KALI-TERMUX.sh — Full Kali XFCE Installer (aarch64)
# Author: Azhar | Hackers Colony

set -euo pipefail

GREEN="\e[92m"
CYAN="\e[96m"
BOLD="\e[1m"
RESET="\e[0m"

clear
echo -e "${GREEN}${BOLD}HCO KALI in Termux by Azhar${RESET}"
echo ""

echo -e "${CYAN}[+] Preparing Termux...${RESET}"
pkg update -y && pkg upgrade -y
pkg install wget proot-distro tar -y

echo -e "${CYAN}[+] Downloading full Kali Linux rootfs...${RESET}"
mkdir -p $PREFIX/var/lib/proot-distro/tarballs
cd $PREFIX/var/lib/proot-distro/tarballs

wget -O kali-rootfs.tar.xz \
"https://github.com/EXALAB/AnLinux-Resources/releases/download/rootfs/kalifs-arm64-full.tar.xz"

echo -e "${CYAN}[+] Installing Kali...${RESET}"
proot-distro install --override-alias kali kali-rootfs.tar.xz

echo -e "${CYAN}[+] Configuring Kali...${RESET}"
proot-distro login kali -- << 'EOF'
apt update
apt install xfce4 xfce4-goodies dbus-x11 -y
apt install firefox-esr nano git curl wget nmap -y
EOF

echo -e "${CYAN}[✓] Kali Linux installed✔${RESET}"
sleep 2
clear

echo -e "${GREEN}${BOLD}✔ HCO KALI in Termux Installed Successfully${RESET}"
echo ""
echo -e "${CYAN}VNC Login Details:${RESET}"
echo "Address  : 127.0.0.1:8081"
echo "Username : HCOKali"
echo "Password : HCO786"
echo ""
echo "To start VNC server manually:"
echo "  proot-distro login kali -- vncserver :1 -geometry 1280x720 -rfbport 8081 -localhost no"
echo ""
echo "To enter Kali shell:"
echo "  proot-distro login kali"
echo ""
echo -e "${GREEN}Enjoy Kali Linux ✔${RESET}"
