#!/usr/bin/env bash
# HCO-KALI-TERMUX.sh
# HCO KALI in Termux by Azhar — BASIC (XFCE) installer
# User: HCOKali  /  Pass: HCO786
set -euo pipefail

# ---------- Colors & UI ----------
G="\e[1;32m"; C="\e[1;36m"; Y="\e[1;33m"; R="\e[1;31m"; BOLD="\e[1m"; RST="\e[0m"
TITLE="${G}${BOLD}HCO KALI in Termux by Azhar${RST}"

# ---------- Config ----------
DIST_PREFS=(kali ubuntu debian)
DIST_CHOSEN=""
USERNAME="HCOKali"
PASSWORD="HCO786"
VNC_PORT=8081

clear
echo -e "${TITLE}\n"
echo -e "${C}This installer sets up a BASIC Kali-like environment (XFCE) inside Termux.${RST}"
echo

# ---------- TOOL LOCK (short & clear) ----------
echo -e "${Y}TOOL LOCKED 🔒 — Subscribe to unlock${RST}"
for i in 9 8 7 6 5 4 3 2 1; do
  echo -e "${G}${i}${RST}"
  sleep 1
done
termux-open-url "https://youtube.com/@hackers_colony_tech"
read -p $'\e[1;32mPress ENTER after subscribing to continue...\e[0m'

clear
echo -e "${G}Starting HCO KALI TERMUX (BASIC XFCE)...${RST}"
sleep 1

# ---------- Ensure proot-distro present ----------
if ! command -v proot-distro >/dev/null 2>&1; then
  echo -e "${Y}Installing proot-distro...${RST}"
  pkg update -y
  pkg install -y proot-distro wget tar
fi

# ---------- Choose distro available in proot-distro registry ----------
echo -e "${C}Detecting available distro...${RST}"
AVAILABLE="$(proot-distro list 2>/dev/null | tr '\n' ' ' || true)"

for d in "${DIST_PREFS[@]}"; do
  if echo "$AVAILABLE" | grep -iq "^$d"; then
    DIST_CHOSEN="$d"
    break
  fi
done

# If none matched, try common aliases
if [ -z "$DIST_CHOSEN" ]; then
  if echo "$AVAILABLE" | grep -qi "ubuntu"; then DIST_CHOSEN="ubuntu"; fi
  if [ -z "$DIST_CHOSEN" ] && echo "$AVAILABLE" | grep -qi "debian"; then DIST_CHOSEN="debian"; fi
fi

if [ -z "$DIST_CHOSEN" ]; then
  echo -e "${R}No suitable distro found in proot-distro registry.${RST}"
  echo -e "${R}Run 'proot-distro list' and tell me what you see, or install proot-distro package sources.${RST}"
  exit 1
fi

echo -e "${G}Will use distro: ${BOLD}${DIST_CHOSEN}${RST}"

# ---------- Install distro if missing ----------
if ! proot-distro list | grep -qi "^${DIST_CHOSEN}"; then
  echo -e "${C}Installing ${DIST_CHOSEN}... (may take several minutes)${RST}"
  proot-distro install "${DIST_CHOSEN}" || { echo -e "${R}Failed to install ${DIST_CHOSEN}.${RST}"; exit 1; }
else
  echo -e "${G}${DIST_CHOSEN} already installed.${RST}"
fi

# ---------- Inside distro: install XFCE, VNC, create user ----------
echo -e "${C}Configuring desktop environment inside ${DIST_CHOSEN}...${RST}"

# Build a heredoc script to run inside distro
TMP_SCRIPT=$(mktemp)
cat > "$TMP_SCRIPT" <<'IN_DISTRO'
set -e
export DEBIAN_FRONTEND=noninteractive

apt update -y || true
apt install -y xfce4 xfce4-goodies tightvncserver dbus-x11 sudo nano || true

# create user if missing
if ! id "HCOKali" >/dev/null 2>&1; then
  useradd -m -s /bin/bash HCOKali || true
  echo "HCOKali:HCO786" | chpasswd || true
  usermod -aG sudo HCOKali || true
fi

# prepare vnc startup for HCOKali
USER_HOME="/home/HCOKali"
mkdir -p "${USER_HOME}/.vnc"
cat > "${USER_HOME}/.vnc/xstartup" <<'XSU'
#!/bin/sh
xrdb $HOME/.Xresources
startxfce4 &
XSU
chmod +x "${USER_HOME}/.vnc/xstartup"
chown -R HCOKali:HCOKali "${USER_HOME}" || true

# set VNC password (non-interactive) for HCOKali
printf 'HCO786\nHCO786\n' | su - HCOKali -c 'vncpasswd -f > $HOME/.vnc/passwd' || true
su - HCOKali -c 'chmod 600 $HOME/.vnc/passwd' || true

echo "SETUP_DONE"
IN_DISTRO

# Run the setup inside the distro
proot-distro login "${DIST_CHOSEN}" -- bash -s < "$TMP_SCRIPT" || { echo -e "${R}Failed configuring desktop inside distro.${RST}"; rm -f "$TMP_SCRIPT"; exit 1; }
rm -f "$TMP_SCRIPT"

# ---------- Create helper launch scripts in CWD ----------
cat > start-${DIST_CHOSEN}.sh <<EOF
#!/usr/bin/env bash
# launch shell inside ${DIST_CHOSEN}
proot-distro login ${DIST_CHOSEN}
EOF
chmod +x start-${DIST_CHOSEN}.sh

cat > start-vnc-${DIST_CHOSEN}.sh <<EOF
#!/usr/bin/env bash
# start VNC server (run inside host; will execute inside distro)
proot-distro login ${DIST_CHOSEN} -- su - HCOKali -c "vncserver :1 -geometry 1280x720 -rfbport ${VNC_PORT} -localhost no"
EOF
chmod +x start-vnc-${DIST_CHOSEN}.sh

# ---------- Final summary ----------
clear
echo -e "${G}${BOLD}HCO KALI in Termux by Azhar — BASIC setup complete${RST}"
echo
echo -e "${C}VNC Login Details:${RST}"
echo -e "${G}Address : ${BOLD}127.0.0.1:${VNC_PORT}${RST}"
echo -e "${G}Username: ${BOLD}${USERNAME}${RST}"
echo -e "${G}Password: ${BOLD}${PASSWORD}${RST}"
echo
echo -e "${Y}To start the VNC server manually run:${RST}"
echo -e "  ${C}./start-vnc-${DIST_CHOSEN}.sh${RST}"
echo
echo -e "${Y}To open an interactive shell inside the distro run:${RST}"
echo -e "  ${C}./start-${DIST_CHOSEN}.sh   (or)   proot-distro login ${DIST_CHOSEN}${RST}"
echo
echo -e "${G}Files created in current folder:${RST}"
echo -e "  ${C}start-${DIST_CHOSEN}.sh${RST}"
echo -e "  ${C}start-vnc-${DIST_CHOSEN}.sh${RST}"
echo
echo -e "${G}If anything failed, paste the exact error output and I will fix it.${RST}"
