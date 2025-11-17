#!/usr/bin/env bash
# ---------------------------------------------------------
#   HCO KALI Termux - by Azhar
#   Auto Kali + Auto VNC Setup + Show Address & Password
# ---------------------------------------------------------

# Colors
GRN='\033[1;32m'
RED='\033[1;31m'
CYN='\033[1;36m'
YLW='\033[1;33m'
RST='\033[0m'

clear

echo -e "${GRN}"
echo -e "############################################"
echo -e "#                                          #"
echo -e "#           HCO KALI Termux               #"
echo -e "#               by Azhar                  #"
echo -e "#                                          #"
echo -e "############################################"
echo -e "${RST}\n"

echo -e "${CYN}[+] Updating Termux...${RST}"
pkg update -y && pkg upgrade -y

echo -e "${CYN}[+] Installing required tools...${RST}"
pkg install proot-distro wget -y

# Install Kali only once
if ! proot-distro list | grep -q "kali"; then
    echo -e "${YLW}[+] Installing Kali Linux (first time setup)...${RST}"
    proot-distro install kali
else
    echo -e "${GRN}[✓] Kali is already installed.${RST}"
fi

# Launch script added
cat << 'EOF' > $PREFIX/bin/kali
#!/bin/bash
proot-distro login kali --shared-tmp -- bash
EOF

chmod +x $PREFIX/bin/kali

echo -e "${GRN}[✓] Kali setup completed.${RST}"
echo -e "${CYN}[+] Starting Kali for VNC configuration...${RST}"
echo -e "\n"

# Configure VNC inside Kali automatically
proot-distro login kali --shared-tmp -- bash << 'IN_KALI'

# Make VNC folder
mkdir -p ~/.vnc

# Generate a strong default password once
if [ ! -f ~/.vnc/passwd ]; then
    echo "hco123" | vncpasswd -f > ~/.vnc/passwd
    chmod 600 ~/.vnc/passwd
fi

# Kill any previous session
vncserver -kill :1 > /dev/null 2>&1

# Start fresh VNC server
vncserver :1

IN_KALI

# Show connection details
echo -e "${GRN}[✓] RealVNC Server Started Successfully!${RST}\n"

HOST="127.0.0.1"
PORT="5901"
PASS="hco123"
NAME=$(hostname)

echo -e "${CYN}============== VNC DETAILS ==============${RST}"
echo -e "${GRN}Address     : ${YLW}${HOST}:${PORT}${RST}"
echo -e "${GRN}Password    : ${YLW}${PASS}${RST}"
echo -e "${GRN}Computer ID : ${YLW}${NAME}${RST}"
echo -e "${CYN}=========================================${RST}\n"

echo -e "${GRN}[✓] Open VNC Viewer manually and enter above details.${RST}"
echo -e "${YLW}Press Enter to launch Kali shell...${RST}"
read

kali
