#!/data/data/com.termux/files/usr/bin/bash
clear

# -------- COLORS --------
G="\033[1;32m"
R="\033[1;31m"
Y="\033[1;33m"
C="\033[1;36m"
W="\033[1;37m"
B="\033[1m"
NC="\033[0m"

TITLE="${G}${B}HCO KALI in Termux by Azhar${NC}"
YOUTUBE_URL="https://youtube.com/@hackers_colony_tech"

# -------- SIMPLE CLEAN BANNER --------
banner() {
    clear
    echo -e "$TITLE"
    echo -e "${C}${B}Full Kali Linux • XFCE • Auto VNC${NC}"
    echo
}

banner

# --------- SUBSCRIBE LOCK ---------
echo -e "${R}${B}[TOOL LOCKED]${NC}"
echo -e "${G}Subscribe to unlock HCO KALI TERMUX${NC}"
echo -e "${Y}Redirecting in...${NC}"

for i in 9 8 7 6 5 4 3 2 1; do
    echo -e "${G}$i${NC}"
    sleep 1
done

termux-open-url "$YOUTUBE_URL"
echo
echo -e "${G}${B}After subscribing, Press ENTER to unlock...${NC}"
read

banner
echo -e "${G}[UNLOCKED] Starting installation...${NC}"
sleep 1
clear
banner

# -------- PACKAGES --------
echo -e "${Y}Updating packages...${NC}"
pkg update -y
pkg install -y proot-distro wget tar

# -------- DOWNLOAD FULL KALI ROOTFS --------
banner
echo -e "${G}Downloading Full Kali Linux RootFS (500MB)...${NC}"
wget -O kali-rootfs.tar.xz https://kali.download/nethunter-images/current/rootfs/kalifs-arm64-full.tar.xz

# -------- INSTALL KALI --------
banner
echo -e "${C}Extracting RootFS (This will take time)...${NC}"

proot-distro remove kali 2>/dev/null
proot-distro install --override-alias kali --tarball kali-rootfs.tar.xz

# -------- CONFIGURE XFCE + VNC --------
banner
echo -e "${G}Configuring XFCE Desktop & VNC...${NC}"

cat > /data/data/com.termux/files/usr/var/lib/proot-distro/kali/root/.vnc/xstartup << "EOF"
#!/bin/sh
xrdb $HOME/.Xresources
startxfce4 &
EOF

chmod +x /data/data/com.termux/files/usr/var/lib/proot-distro/kali/root/.vnc/xstartup

# -------- SET RANDOM VNC PASSWORD --------
VNC_PASS="kali$(shuf -i 1000-9999 -n 1)"

proot-distro login kali --user root --shared-tmp <<EOF
mkdir -p /root/.vnc
echo "$VNC_PASS" | vncpasswd -f > /root/.vnc/passwd
chmod 600 /root/.vnc/passwd
EOF

# -------- START VNC SERVER --------
banner
echo -e "${Y}Starting VNC Server...${NC}"

proot-distro login kali --user root --shared-tmp vncserver :1

VNC_ADDR="127.0.0.1:5901"

# -------- SHOW DETAILS --------
banner
echo -e "${C}${B}FULL KALI INSTALLED SUCCESSFULLY${NC}"
echo
echo -e "${Y}🌐 VNC Address: ${G}$VNC_ADDR${NC}"
echo -e "${Y}🔑 VNC Password: ${R}${B}$VNC_PASS${NC}"
echo -e "${Y}👤 Login User: ${G}root${NC}"
echo
echo -e "${C}Opening RealVNC Viewer...${NC}"
sleep 2

am start -n com.realvnc.viewer.android/.app.ConnectionEditActivity >/dev/null 2>&1

echo
echo -e "${G}${B}Press ENTER to start Kali shell${NC}"
read

proot-distro login kali --user root
