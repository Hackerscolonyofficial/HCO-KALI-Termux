#!/data/data/com.termux/files/usr/bin/bash
# HCO-KALI-TERMUX by Azhar | Hackers Colony
# Fully working Kali ARM64 + XFCE GUI + Termux-X11

set -e

GREEN="\033[1;32m"
YELLOW="\033[1;33m"
CYAN="\033[1;36m"
RESET="\033[0m"

YOUTUBE_LINK="https://youtube.com/@hackers_colony_tech?si=pvdCWZggTIuGb0ya"
KALI_ROOTFS_URL="https://github.com/EXALAB/AnLinux-Resources/releases/download/rootfs/kalifs-arm64-full.tar.xz"

# --------------------------
# TOOL LOCK - SUBSCRIBE
# --------------------------
echo -e "${GREEN}HCO KALI TERMUX by Azhar${RESET}"
echo -e "${YELLOW}This tool is locked 🔒"
echo -e "Subscribe to unlock 🔓${RESET}"
echo -e "${CYAN}Redirecting in 9 seconds...${RESET}"
for i in {9..1}; do
    echo -e "${GREEN}$i${RESET}"
    sleep 1
done

termux-open-url "$YOUTUBE_LINK"
read -p $'\033[1;36mAfter subscribing, press ENTER to continue...\033[0m'

clear
echo -e "${GREEN}Unlock Successful ✔${RESET}"
sleep 1

# --------------------------
# INSTALL REQUIRED PACKAGES
# --------------------------
echo -e "${CYAN}[+] Installing required packages...${RESET}"
pkg update -y
pkg install wget proot-distro pulseaudio termux-x11 tar -y

# --------------------------
# DOWNLOAD & INSTALL KALI ROOTFS
# --------------------------
echo -e "${CYAN}[+] Installing Kali ARM64 rootfs...${RESET}"

if ! proot-distro list | grep -q "^kali"; then
    mkdir -p ~/kali-rootfs
    cd ~/kali-rootfs
    echo -e "${YELLOW}Downloading Kali rootfs... This may take several minutes${RESET}"
    wget -O kalifs-arm64-full.tar.xz "$KALI_ROOTFS_URL"
    echo -e "${CYAN}Installing Kali in proot-distro...${RESET}"
    proot-distro install --override-alias kali --tarball kalifs-arm64-full.tar.xz
else
    echo -e "${GREEN}Kali already installed, skipping...${RESET}"
fi

# --------------------------
# CREATE START SCRIPTS
# --------------------------
echo -e "${CYAN}[+] Creating start scripts...${RESET}"

# Start Kali shell
cat > start-kali.sh << 'EOF'
#!/data/data/com.termux/files/usr/bin/bash
pulseaudio --start --exit-idle-time=-1 >/dev/null 2>&1
proot-distro login kali
EOF
chmod +x start-kali.sh

# Start GUI XFCE + VNC
cat > start-x11.sh << 'EOF'
#!/data/data/com.termux/files/usr/bin/bash
echo -e "\033[1;32mStarting Termux-X11 and VNC...\033[0m"
pulseaudio --start --exit-idle-time=-1 >/dev/null 2>&1
vncserver :1 -geometry 1280x720 -localhost no -rfbport 8081
proot-distro login kali --command "startxfce4 &"
echo -e "\033[1;32mVNC Login Details:\033[0m"
echo -e "Address  : 127.0.0.1:8081"
echo -e "Username : HCOKali"
echo -e "Password : HCO786"
echo -e "To enter Kali shell: ./start-kali.sh"
EOF
chmod +x start-x11.sh

# Stop GUI
cat > stop-kali.sh << 'EOF'
#!/data/data/com.termux/files/usr/bin/bash
pkill pulseaudio
pkill -f startxfce4
pkill -f Xtightvnc
echo "XFCE stopped."
EOF
chmod +x stop-kali.sh

# --------------------------
# FINISH MESSAGE
# --------------------------
clear
echo -e "${GREEN}HCO KALI TERMUX by Azhar ✅${RESET}"
echo -e "${CYAN}Start GUI: ./start-x11.sh${RESET}"
echo -e "${CYAN}Enter Kali shell: ./start-kali.sh${RESET}"
echo -e "${YELLOW}Enjoy Kali Linux XFCE inside Termux!${RESET}"
