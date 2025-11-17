#!/usr/bin/env bash
# HCO KALI TERMUX — Full Kali Linux Installer (aarch64)
# File: HCO-KALI-TERMUX.sh
# Code by Azhar | Hackers Colony

GREEN="\e[92m"
CYAN="\e[96m"
YELLOW="\e[93m"
BOLD="\e[1m"
RESET="\e[0m"

clear
echo -e "${GREEN}${BOLD}HCO KALI in Termux${RESET}"
echo -e "${CYAN}${BOLD}by Azhar | Hackers Colony${RESET}"
echo

# ---------- TOOL LOCK ----------
echo -e "${YELLOW}${BOLD}This tool is locked 🔒"
echo -e "Subscribe to unlock 🔓${RESET}"
echo

for i in {9..1}; do
    echo -e "${GREEN}${BOLD}$i${RESET}"
    sleep 1
done

termux-open-url "https://youtube.com/@hackers_colony_tech"
sleep 2
read -p "Press ENTER after subscribing... "

clear

# ---------- INSTALL DEPENDENCIES ----------
echo -e "${CYAN}${BOLD}[+] Installing required packages...${RESET}"
pkg update -y
pkg install wget proot tar xz-utils -y

# ---------- DOWNLOAD FULL KALI ROOTFS ----------
ROOTFS_URL="https://kali.download/nethunter-images/current/rootfs/kalifs-arm64-full.tar.xz"

mkdir -p kali-fs
cd kali-fs

echo -e "${CYAN}${BOLD}[+] Downloading Full Kali rootfs (1.2GB)...${RESET}"
wget -O kali.tar.xz "$ROOTFS_URL" || { echo "Download failed!"; exit 1; }

echo -e "${CYAN}${BOLD}[+] Extracting Kali rootfs (3–5 minutes)...${RESET}"
tar -xJf kali.tar.xz || { echo -e "${RED}Extraction failed!${RESET}"; exit 1; }

rm kali.tar.xz
cd ..

# ---------- CREATE KALI LAUNCHER ----------
cat > start-kali.sh << 'EOF'
#!/usr/bin/env bash
unset LD_PRELOAD
proot --link2symlink -0 -r kali-fs \
-b /dev -b /proc -b /sys -b /data/data/com.termux/files/home \
-w /root /usr/bin/env -i HOME=/root PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin \
/bin/bash --login
EOF

chmod +x start-kali.sh

# ---------- SUCCESS MESSAGE ----------
clear
echo -e "${GREEN}${BOLD}✔ HCO KALI TERMUX Installed Successfully${RESET}"
echo
echo -e "${CYAN}${BOLD}VNC Login Details:${RESET}"
echo -e "${GREEN}Address : ${BOLD}127.0.0.1:8081${RESET}"
echo -e "${GREEN}Username: ${BOLD}HCOKali${RESET}"
echo -e "${GREEN}Password: ${BOLD}HCO786${RESET}"
echo
echo -e "${YELLOW}To start VNC inside Kali (run this after entering Kali):${RESET}"
echo -e "${CYAN}vncserver :1 -geometry 1280x720 -localhost no -rfbport 8081${RESET}"
echo
echo -e "${YELLOW}To enter Kali shell:${RESET}"
echo -e "${CYAN}./start-kali.sh${RESET}"
echo

read -p "Press ENTER to launch Kali shell... "
./start-kali.sh
