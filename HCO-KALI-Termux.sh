#!/usr/bin/env bash
# HCO KALI TERMUX — Full Kali Linux Installer (proot-distro)
# File: HCO-KALI-TERMUX.sh
# Code by Azhar | Hackers Colony

GREEN="\e[92m"; CYAN="\e[96m"; YELLOW="\e[93m"; BOLD="\e[1m"; RESET="\e[0m"

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
echo -e "${CYAN}${BOLD}[+] Installing packages...${RESET}"
pkg update -y
pkg install proot-distro wget tar x11-repo -y

# ---------- INSTALL OFFICIAL KALI ----------
echo -e "${CYAN}${BOLD}[+] Installing Full Kali Linux (no external links)...${RESET}"
proot-distro install kali || { echo -e "${RED}Kali install failed!${RESET}"; exit 1; }

# ---------- CREATE START SCRIPT ----------
cat > start-kali.sh << 'EOF'
#!/usr/bin/env bash
proot-distro login kali
EOF

chmod +x start-kali.sh

# ---------- SHOW CREDENTIALS ----------
clear
echo -e "${GREEN}${BOLD}✔ HCO KALI TERMUX Installed Successfully${RESET}"
echo
echo -e "${CYAN}${BOLD}VNC Login Details:${RESET}"
echo -e "${GREEN}Address : ${BOLD}127.0.0.1:8081${RESET}"
echo -e "${GREEN}Username: ${BOLD}HCOKali${RESET}"
echo -e "${GREEN}Password: ${BOLD}HCO786${RESET}"
echo
echo -e "${YELLOW}Start VNC manually inside Kali:${RESET}"
echo -e "${CYAN}vncserver :1 -geometry 1280x720 -localhost no -rfbport 8081${RESET}"
echo
echo -e "${YELLOW}To enter Kali shell:${RESET}"
echo -e "${CYAN}./start-kali.sh${RESET}"
echo
read -p "Press ENTER to launch Kali shell... "
./start-kali.sh
