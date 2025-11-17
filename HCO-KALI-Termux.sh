#!/usr/bin/env bash
# HCO KALI in Termux by Azhar
# Full Kali Linux (Nethunter rootfs) Auto Installer
# Clean UI • Green Hacker Theme • Fixed Paths • No Errors

set -e

# ---------- COLORS ----------
green="\e[1;32m"
yellow="\e[1;33m"
red="\e[1;31m"
blue="\e[1;34m"
reset="\e[0m"
bold="\e[1m"

clear

echo -e "${green}${bold}HCO KALI in Termux by Azhar${reset}"
echo
echo -e "${yellow}${bold}Tool Locked 🔒${reset}"
echo -e "${green}Subscribe to unlock the tool 🔓${reset}"
echo

# Countdown + redirect
for i in 9 8 7 6 5 4 3 2 1; do
  echo -e "${green}Redirecting in $i...${reset}"
  sleep 1
done

termux-open-url "https://youtube.com/@hackers_colony_tech"

echo
read -p "Press ENTER after subscribing to continue..." ok

clear
echo -e "${green}${bold}Starting HCO KALI Installer...${reset}"
sleep 1

# ---------- PREPARE DIRECTORIES ----------
mkdir -p $HOME/kali-fs
cd $HOME

# ---------- DOWNLOAD FULL KALI ROOTFS ----------
echo -e "${green}Downloading Full Kali Linux rootfs (arm64)...${reset}"
curl -L -o kali-rootfs.tar.xz \
  https://kali.download/nethunter-images/current/rootfs/kalifs-arm64-full.tar.xz

echo -e "${green}Extracting Kali rootfs... This may take 2–4 minutes.${reset}"

proot --link2symlink tar -xJf kali-rootfs.tar.xz -C kali-fs

# ---------- FIX PERMISSIONS ----------
cd $HOME/kali-fs
mkdir -p dev proc sys tmp root home

# ---------- CREATE start-kali.sh ----------
cd $HOME
cat > start-kali.sh <<'EOF'
#!/usr/bin/env bash
cd $HOME/kali-fs

exec proot \
 --kill-on-exit \
 --link2symlink \
 --rootfs=$HOME/kali-fs \
 -0 \
 -b /dev \
 -b /proc \
 -b /sys \
 -b /data/data/com.termux \
 -b $HOME \
 /usr/bin/env -i HOME=/root PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin SHELL=/bin/bash TERM=xterm-256color /bin/bash --login
EOF

chmod +x start-kali.sh

# ---------- INSTALL XFCE + VNC INSIDE KALI ----------
echo -e "${green}Installing XFCE Desktop + VNC server (inside Kali)...${reset}"
$HOME/start-kali.sh <<'EOF'
apt update -y
apt install -y xfce4 xfce4-goodies tightvncserver dbus-x11
EOF

# ---------- CREATE VNC PASSWORD ----------
echo -e "${green}Setting VNC password...${reset}"
$HOME/start-kali.sh <<EOF
mkdir -p /root/.vnc
echo -e "HCO786\nHCO786\n" | vncpasswd
EOF

# ---------- VNC STARTER SCRIPT ----------
cat > vnc-start.sh <<'EOF'
#!/usr/bin/env bash
$HOME/start-kali.sh <<'INCHroot'
vncserver :1 -geometry 1280x720 -rfbport 8081 -localhost no
INCHroot
EOF

chmod +x vnc-start.sh

# ---------- UI OUTPUT ----------
clear
echo -e "${green}${bold}HCO KALI in Termux by Azhar${reset}"
echo
echo -e "${yellow}${bold}VNC Login Details:${reset}"
echo -e "${green}Address : 127.0.0.1:8081${reset}"
echo -e "${green}Username: HCOKali${reset}"
echo -e "${green}Password: HCO786${reset}"
echo
echo -e "${yellow}To START the VNC server manually:${reset}"
echo -e "${green}  bash vnc-start.sh${reset}"
echo
echo -e "${yellow}To ENTER Kali shell:${reset}"
echo -e "${green}  ./start-kali.sh${reset}"
echo
read -p "Press ENTER to launch Kali shell..." ok

./start-kali.sh
