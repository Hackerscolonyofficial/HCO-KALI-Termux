#!/usr/bin/env bash
# HCO KALI TERMUX — Full Kali + XFCE (NO AUTO VNC)
# Created by Azhar | Hackers Colony

clear

# ---------- COLOURS ----------
green="\e[92m"; yellow="\e[93m"; cyan="\e[96m"; bold="\e[1m"; reset="\e[0m"

# ---------- HEADER ----------
echo -e "${green}${bold}HCO KALI in Termux by Azhar${reset}\n"

# ---------- TOOL LOCK ----------
echo -e "${yellow}${bold}This tool is locked 🔒"
echo -e "Subscribe to unlock 🔓${reset}\n"

for i in 9 8 7 6 5 4 3 2 1; do
    echo -e "${green}${bold}$i${reset}"
    sleep 1
done

termux-open-url "https://youtube.com/@hackers_colony_tech"
sleep 3
read -p $'\e[92mPress ENTER after subscribing...\e[0m'

clear
echo -e "${green}${bold}Starting HCO KALI TERMUX installation...${reset}\n"
sleep 1

# ---------- INSTALL BASICS ----------
pkg update -y
pkg install -y wget proot tar proot-distro

# ---------- CREATE KALI DIRECTORY ----------
mkdir -p ~/kali-fs
cd ~/kali-fs

# ---------- DOWNLOAD OFFICIAL ROOTFS ----------
echo -e "${cyan}${bold}Downloading Kali rootfs (aarch64)...${reset}"

wget -O kali-rootfs.tar.xz \
https://kali.download/base-images/kali-2024.4/kali-linux-2024.4-base-arm64.tar.xz

if [ ! -f kali-rootfs.tar.xz ]; then
    echo -e "${red}Download failed! Check internet.${reset}"
    exit
fi

# ---------- EXTRACT ----------
echo -e "${green}${bold}Extracting Kali rootfs...${reset}"
tar -xvf kali-rootfs.tar.xz > /dev/null 2>&1

# ---------- CREATE START SCRIPT ----------
cd ~

cat > start-kali.sh << 'EOF'
#!/data/data/com.termux/files/usr/bin/bash
cd ~/kali-fs
proot --link2symlink -0 -r . \
-b /dev -b /proc -b /sys -b /data/data/com.termux \
-w /root /usr/bin/env -i \
HOME=/root PATH=/bin:/usr/bin:/sbin:/usr/sbin \
/bin/bash --login
EOF

chmod +x start-kali.sh

# ---------- INSTALL XFCE ----------
echo -e "${cyan}${bold}Installing XFCE desktop inside Kali...${reset}"

./start-kali.sh << 'INSIDE'
apt update -y
apt install -y xfce4 xfce4-goodies tigervnc-standalone-server dbus-x11
INSIDE

# ---------- SETUP VNC PASSWORD ----------
echo -e "${green}${bold}Configuring VNC password...${reset}"

./start-kali.sh << 'INSIDE'
mkdir -p /root/.vnc
echo -e "HCO786\nHCO786\nn" | vncpasswd
INSIDE

# ---------- CREATE XSTARTUP ----------
./start-kali.sh << 'INSIDE'
echo '#!/bin/bash
xrdb $HOME/.Xresources
startxfce4 &' > /root/.vnc/xstartup
chmod +x /root/.vnc/xstartup
INSIDE

# ---------- DONE ----------
clear

echo -e "${green}${bold}HCO KALI TERMUX is ready!${reset}\n"

echo -e "${cyan}${bold}VNC Login Details:${reset}"
echo -e "${yellow}${bold}Address : 127.0.0.1:8081${reset}"
echo -e "${yellow}${bold}Username: HCOKali${reset}"
echo -e "${yellow}${bold}Password: HCO786${reset}\n"

echo -e "${green}${bold}To enter Kali shell:${reset}"
echo -e "${cyan}./start-kali.sh${reset}\n"

echo -e "${green}${bold}(You will manually start the VNC server)${reset}\n"

read -p $'\e[92mPress ENTER to launch Kali shell...\e[0m'

./start-kali.sh
