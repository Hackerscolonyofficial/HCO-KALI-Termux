#!/usr/bin/env bash
# HCO KALI TERMUX — Full Kali Linux + XFCE + VNC
# Created by Azhar (Hackers Colony)

clear

# ---------- Colours ----------
green="\e[92m"
cyan="\e[96m"
red="\e[91m"
yellow="\e[93m"
bold="\e[1m"
reset="\e[0m"

# ---------- Header ----------
echo -e "${green}${bold}"
echo "HCO KALI in Termux by Azhar"
echo -e "${reset}"

# ---------- Tool Lock ----------
echo -e "${yellow}${bold}This tool is locked 🔒"
echo -e "Subscribe to unlock 🔓${reset}"
echo ""

for i in 9 8 7 6 5 4 3 2 1; do
    echo -e "${green}${bold}$i${reset}"
    sleep 1
done

# Redirect
termux-open-url "https://youtube.com/@hackers_colony_tech"
sleep 4

read -p $'\e[92mPress ENTER after subscribing to continue...\e[0m'

clear

# ---------- Start Installer ----------
echo -e "${green}${bold}Starting HCO KALI TERMUX installation...${reset}"
sleep 2

# Update packages
pkg update -y && pkg upgrade -y
pkg install -y proot-distro wget xfce4 tigervnc

# ---------- Install Full Kali ----------
echo -e "${cyan}${bold}Downloading & installing full Kali Linux (rootfs)...${reset}"
proot-distro install kali

clear
echo -e "${green}${bold}Kali installed successfully!${reset}"
sleep 2

# ---------- Configure XFCE Inside Kali ----------
echo -e "${cyan}${bold}Configuring XFCE desktop inside Kali...${reset}"

proot-distro login kali -- bash -c "
apt update -y
apt install -y xfce4 xfce4-goodies dbus-x11 tightvncserver
"

# ---------- Create VNC Startup Script ----------
echo -e "${cyan}${bold}Setting up VNC server (Port: 8081)...${reset}"

proot-distro login kali -- bash -c "
mkdir -p ~/.vnc
echo '#!/bin/bash
xrdb ~/.Xresources
startxfce4 &' > ~/.vnc/xstartup
chmod +x ~/.vnc/xstartup
"

# ---------- Set VNC Password ----------
echo -e "${green}${bold}Setting VNC password...${reset}"

proot-distro login kali -- bash -c "
echo -e 'HCO786\nHCO786\nn' | vncserver :1
vncserver -kill :1
"

# ---------- Display Connection Info ----------
clear
echo -e "${green}${bold}HCO KALI TERMUX is ready!${reset}"
echo ""
echo -e "${cyan}${bold}Connect VNC using:${reset}"
echo -e "${yellow}${bold}Address : 127.0.0.1:8081${reset}"
echo -e "${yellow}${bold}Username: HCOKali${reset}"
echo -e "${yellow}${bold}Password: HCO786${reset}"
echo ""
echo -e "${green}${bold}To start VNC server run:${reset}"
echo -e "${cyan}proot-distro login kali -- vncserver :1 -geometry 1280x720 -localhost no -rfbport 8081${reset}"
echo ""
echo -e "${green}${bold}To enter Kali shell run:${reset}"
echo -e "${cyan}proot-distro login kali${reset}"
echo ""

read -p $'\e[92mPress ENTER to launch Kali shell...\e[0m'

proot-distro login kali
