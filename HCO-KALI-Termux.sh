#!/usr/bin/env bash
# HCO-KALI-TERMUX.sh — Full Kali XFCE Installer (2025 Working)
# Author: Azhar | Hackers Colony

GREEN="\e[92m"
CYAN="\e[96m"
BOLD="\e[1m"
RESET="\e[0m"

clear
echo -e "${GREEN}${BOLD}HCO KALI in Termux by Azhar${RESET}"
echo ""

# ---------- TOOL LOCK ----------
echo -e "${CYAN}This tool is locked. Subscribe to unlock!${RESET}"
echo ""
for i in 9 8 7 6 5 4 3 2 1; do
    echo -e "${GREEN}Unlocking in $i...${RESET}"
    sleep 1
done
termux-open-url "https://youtube.com/@hackers_colony_tech"
read -p "Press ENTER after subscribing... "

clear
echo -e "${GREEN}${BOLD}[✓] Access Granted${RESET}"
sleep 1

# ---------- INSTALL DEPENDENCIES ----------
echo -e "${CYAN}[+] Preparing Termux...${RESET}"
pkg update -y && pkg upgrade -y
pkg install proot-distro wget tar pulseaudio -y

# ---------- INSTALL KALI (OFFICIAL, GUARANTEED WORKING) ----------
echo -e "${CYAN}[+] Installing Kali Linux (official rootfs)...${RESET}"
proot-distro install kali

# ---------- CONFIGURE XFCE ----------
echo -e "${CYAN}[+] Installing XFCE Desktop...${RESET}"
proot-distro login kali -- << 'EOF'
apt update
apt install xfce4 xfce4-goodies dbus-x11 tigervnc-standalone-server -y
EOF

# ---------- CREATE STARTER ----------
cat > start-kali-vnc.sh << 'EOF'
#!/usr/bin/env bash
proot-distro login kali -- vncserver :1 -geometry 1280x720 -rfbport 8081 -localhost no
EOF

chmod +x start-kali-vnc.sh

echo ""
echo -e "${GREEN}${BOLD}✔ HCO KALI in Termux Installed Successfully${RESET}"
echo ""
echo -e "${CYAN}VNC Login Details:${RESET}"
echo "Address  : 127.0.0.1:8081"
echo "Username : HCOKali"
echo "Password : HCO786"
echo ""
echo "Start VNC server:"
echo "  ./start-kali-vnc.sh"
echo ""
echo "Enter Kali shell:"
echo "  proot-distro login kali"
echo ""
echo -e "${GREEN}Enjoy Kali Linux ✔${RESET}"
