#!/usr/bin/env bash
# ---------------------------------------------------------
#   HCO KALI Termux - by Azhar
#   Full Auto Installer + Auto RealVNC Launcher
# ---------------------------------------------------------

# Colors
GRN='\033[1;32m'
RED='\033[1;31m'
YLW='\033[1;33m'
CYN='\033[1;36m'
RST='\033[0m'

clear

# Banner (Option 2)
echo -e "${GRN}"
echo -e "############################################"
echo -e "#                                          #"
echo -e "#           HCO KALI Termux               #"
echo -e "#               by Azhar                  #"
echo -e "#                                          #"
echo -e "############################################"
echo -e "${RST}\n"

# Update packages
echo -e "${CYN}[+] Updating Termux packages...${RST}"
pkg update -y && pkg upgrade -y


# Install required tools
echo -e "${CYN}[+] Installing required packages...${RST}"
pkg install wget proot-distro -y


# Install Kali (if not already installed)
if ! proot-distro list | grep -q "kali"; then
    echo -e "${YLW}[+] Installing Kali Linux...${RST}"
    proot-distro install kali
else
    echo -e "${GRN}[✓] Kali Linux already installed.${RST}"
fi


# Create launch script
mkdir -p $PREFIX/bin

cat << 'EOF' > $PREFIX/bin/kali
#!/bin/bash
proot-distro login kali --shared-tmp -- env DISPLAY=:1 /bin/bash
EOF

chmod +x $PREFIX/bin/kali


echo -e "\n${GRN}[✓] Installation complete!${RST}"
echo -e "${YLW}Do you want to start RealVNC Server and open VNC Viewer now?${RST}"
echo -e -n "${CYN}Type YES to continue: ${RST}"
read ans

if [[ "$ans" == "YES" || "$ans" == "yes" ]]; then

    echo -e "${GRN}[+] Checking RealVNC server installation...${RST}"

    # Detect VNC server binary
    if command -v vncserver >/dev/null 2>&1; then
        VNC_CMD="vncserver"
    elif command -v realvnc-vncserver >/dev/null 2>&1; then
        VNC_CMD="realvnc-vncserver"
    else
        echo -e "${RED}[✗] RealVNC Server not detected! Install it before running.${RST}"
        exit 1
    fi

    echo -e "${GRN}[✓] RealVNC server detected! Starting...${RST}"

    # Kill old sessions
    pkill -f vncserver >/dev/null 2>&1

    # Start server on display :1
    $VNC_CMD :1 &

    sleep 2

    echo -e "${GRN}[✓] RealVNC Server started on port 5901${RST}"
    echo -e "${CYN}[+] Launching VNC Viewer app...${RST}"

    am start -n com.realvnc.viewer.android/.ui.connect.ConnectActivity >/dev/null 2>&1

    echo -e "${GRN}\n[✓] Done! Open this address in VNC Viewer:\n${RST}"
    echo -e "${YLW}127.0.0.1:5901${RST}"

else
    echo -e "${RED}[-] Exiting...${RST}"
    exit
fi
