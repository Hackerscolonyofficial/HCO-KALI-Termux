#!/usr/bin/env bash
# ---------------------------------------------------------
#      HCO KALI Termux — by Azhar
#      Fully Automated Installer + VNC + YouTube Lock
# ---------------------------------------------------------

# Colors
GRN='\033[1;32m'
CYN='\033[1;36m'
YLW='\033[1;33m'
RED='\033[1;31m'
BLD='\033[1m'
RST='\033[0m'

YOUTUBE_URL="https://youtube.com/@hackers_colony_tech"

# ------------------ YOUTUBE SUBSCRIBE LOCK ------------------

clear
echo -e "${GRN}${BLD}"
echo "#########################################################"
echo "#                                                       #"
echo "#           HCO KALI in Termux — by Azhar              #"
echo "#                                                       #"
echo "#########################################################"
echo -e "${RST}"

echo -e "${RED}${BLD}[🔒 TOOL LOCKED]${RST}"
echo -e "${GRN}${BLD}Subscribe to Hackers Colony to unlock this tool!${RST}"
echo -e "${YLW}${BLD}Redirecting in...${RST}"

for i in 9 8 7 6 5 4 3 2 1; do
    echo -e "${GRN}${BLD}$i...${RST}"
    sleep 1
done

echo -e "${CYN}${BLD}Opening YouTube... Please subscribe and return.${RST}"
sleep 1
termux-open-url "$YOUTUBE_URL"

echo ""
echo -e "${GRN}${BLD}After subscribing, press ENTER to unlock tool...${RST}"
read
clear

echo -e "${GRN}${BLD}[🔓 TOOL UNLOCKED] Access Granted!${RST}"
sleep 1
clear

# ------------------ MAIN BANNER ------------------

echo -e "${GRN}${BLD}"
echo "#########################################################"
echo "#                                                       #"
echo "#           HCO KALI in Termux — by Azhar              #"
echo "#                                                       #"
echo "#########################################################"
echo -e "${RST}\n"

# ---------------------------------------------------------
# INSTALLATION PROCESS
# ---------------------------------------------------------

echo -e "${CYN}${BLD}[+] Updating Termux...${RST}"
pkg update -y >/dev/null 2>&1
pkg upgrade -y >/dev/null 2>&1

echo -e "${CYN}${BLD}[+] Installing required packages...${RST}"
pkg install proot-distro wget -y >/dev/null 2>&1

# Install Kali
echo -e "${YLW}${BLD}[+] Installing Kali Linux (Auto)...${RST}"
proot-distro install kali >/dev/null 2>&1

echo -e "${GRN}${BLD}[✓] Kali Linux installed successfully.${RST}"

# ---------------------------------------------------------
# KALI CONFIGURATION + VNC SERVER
# ---------------------------------------------------------

echo -e "${CYN}${BLD}[+] Setting up Kali environment...${RST}"

proot-distro login kali --shared-tmp -- bash << 'IN_KALI'
apt update -y
apt install tightvncserver xfce4 -y

USERNAME="hco"
PASSWORD="hco123"
useradd -m -s /bin/bash $USERNAME
echo "$USERNAME:$PASSWORD" | chpasswd

mkdir -p /home/$USERNAME/.vnc
echo "hco123" | vncpasswd -f > /home/$USERNAME/.vnc/passwd
chmod 600 /home/$USERNAME/.vnc/passwd
chown -R $USERNAME:$USERNAME /home/$USERNAME/.vnc

sudo -u $USERNAME vncserver :1
IN_KALI

echo -e "${GRN}${BLD}[✓] VNC Server started successfully.${RST}\n"

# ---------------------------------------------------------
# SHOW DETAILS
# ---------------------------------------------------------

HOST="127.0.0.1"
PORT="5901"
USER="hco"
PASS="hco123"
NAME=$(hostname)

echo -e "${CYN}${BLD}============== YOUR KALI LOGIN DETAILS ==============${RST}"
echo -e "${GRN}${BLD}Username     : ${YLW}${USER}${RST}"
echo -e "${GRN}${BLD}Password     : ${YLW}${PASS}${RST}"
echo -e "${GRN}${BLD}VNC Address  : ${YLW}${HOST}:${PORT}${RST}"
echo -e "${GRN}${BLD}Computer Name: ${YLW}${NAME}${RST}"
echo -e "${CYN}${BLD}======================================================${RST}\n"

echo -e "${GRN}${BLD}[✓] Open RealVNC Viewer and connect to:${RST}"
echo -e "${YLW}${BLD}${HOST}:${PORT}${RST}"
echo ""
echo -e "${GRN}${BLD}Press ENTER to open Kali shell...${RST}"
read

proot-distro login kali
