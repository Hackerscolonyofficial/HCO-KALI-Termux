#!/usr/bin/env bash
# HCO-KALI-Termux.sh — installer (no-root) with auto VNC password, auto IP detect, and bVNC auto-open
# Author: Azhar | Hackers Colony
# Usage: chmod +x HCO-KALI-Termux.sh && bash HCO-KALI-Termux.sh
set -euo pipefail

# -------------------------
# Config
# -------------------------
YOUTUBE_URL="https://youtube.com/@hackers_colony_tech?si=pvdCWZggTIuGb0ya"
DIST_NAME="kali-rolling"
HOME_DIR="${HOME:-/data/data/com.termux/files/home}"
INSTALL_DIR="$HOME_DIR/hco_kali_termux"
BOOTSTRAP="$INSTALL_DIR/bootstrap_kali.sh"
START_DIR="$HOME_DIR/kali-termux"
LOGPREFIX="[HCO-KALI-Termux]"
BVNC_PKG="com.iiordanov.bVNC"
BVNC_MARKET_URI="market://details?id=${BVNC_PKG}"
BVNC_WEB_URL="https://play.google.com/store/apps/details?id=${BVNC_PKG}"
VNC_DISPLAY=":1"
VNC_PORT=5901

# Colors
RED_BG="\033[41m"
GREEN_BOLD="\033[1;32m"
BOLD="\033[1m"
RESET="\033[0m"
YELLOW="\033[1;33m"
CYAN="\033[1;36m"

info(){ printf "%b %s\\n" "$LOGPREFIX" "$*"; }
warn(){ printf "%b %s\\n" "$LOGPREFIX" "$*"; }
err(){ printf "%b %s\\n" "$LOGPREFIX" "$*"; exit 1; }

# -------------------------
# Helpers
# -------------------------
detect_geometry(){
  GEOM="1280x720"
  if command -v wm >/dev/null 2>&1; then
    out=$(wm size 2>/dev/null || true)
    if [[ $out =~ ([0-9]{3,4}x[0-9]{3,4}) ]]; then
      GEOM="${BASH_REMATCH[1]}"
    fi
  fi
  if [[ $GEOM =~ ^([0-9]+)x([0-9]+)$ ]]; then
    W=${BASH_REMATCH[1]}; H=${BASH_REMATCH[2]}
    if [ "$W" -gt 1920 ]; then W=1920; fi
    if [ "$H" -gt 1080 ]; then H=1080; fi
    GEOM="${W}x${H}"
  else
    GEOM="1280x720"
  fi
  printf "%s" "$GEOM"
}

# Determine best local host IP to use for external connections (falls back to 127.0.0.1)
detect_host_ip(){
  ip=""
  # Try ip route to get default interface IP
  if command -v ip >/dev/null 2>&1; then
    ip=$(ip route get 1.1.1.1 2>/dev/null | awk '/src/ {for(i=1;i<=NF;i++){if($i=="src"){print $(i+1); exit}}}')
  fi
  # try hostname -I
  if [ -z "$ip" ] && command -v hostname >/dev/null 2>&1; then
    ip=$(hostname -I 2>/dev/null | awk '{print $1}')
  fi
  # fallback
  if [ -z "$ip" ]; then ip="127.0.0.1"; fi
  printf "%s" "$ip"
}

# -------------------------
# Unlock flow (subscribe + redirect)
# -------------------------
clear
printf "%b\n\n" "${BOLD}🔒 TOOL LOCKED — HCO-KALI-Termux${RESET}"
printf "To unlock this tool and continue you must:\n"
printf "  1) Subscribe to Hackers Colony Tech YouTube channel\n"
printf "  2) Click the bell icon to support the channel\n\n"
printf "%b\n" "${YELLOW}Redirecting to YouTube app in...${RESET}"

colors=( "\033[1;31m" "\033[1;33m" "\033[1;32m" "\033[1;36m" "\033[1;35m" "\033[1;34m" "\033[38;5;208m" "\033[38;5;202m" "\033[38;5;201m" )
count=9
while [ $count -ge 1 ]; do
  col="${colors[$(( (9-count) % ${#colors[@]} ))]}"
  printf "%b %s %b\r" "$col" "  $count  " "$RESET"
  sleep 1
  ((count--))
done
printf "\n\n"

OPENED=0
if command -v termux-open-url >/dev/null 2>&1; then
  termux-open-url "$YOUTUBE_URL" >/dev/null 2>&1 || true
  OPENED=1
fi
if [ $OPENED -eq 0 ] && command -v am >/dev/null 2>&1; then
  am start -a android.intent.action.VIEW -d "$YOUTUBE_URL" >/dev/null 2>&1 || true
  OPENED=1
fi

printf "%b\n" "${CYAN}Opened YouTube (if available). Please subscribe & click the bell. When done, return to Termux and press ENTER to continue.${RESET}"
read -r -p $'\nPress ENTER when you are back in Termux to proceed with installation: '

TITLE="HCO Kali Termux by Azhar"
BAR_WIDTH=60
pad_total=$(( BAR_WIDTH - ${#TITLE} ))
if [ $pad_total -lt 0 ]; then pad_total=0; fi
pad_left=$(( pad_total / 2 ))
pad_right=$(( pad_total - pad_left ))
printf "%b" "${RED_BG}"
printf "%*s" $pad_left " "
printf "%b%s%b" "${GREEN_BOLD}" "${TITLE}" "${RESET}${RED_BG}"
printf "%*s" $pad_right " "
printf "%b\n\n" "${RESET}"

read -r -p "Proceed to install Kali (no-root) inside Termux? [Y/n]: " PROCEED
PROCEED="${PROCEED:-Y}"
if [[ ! "$PROCEED" =~ ^([yY]|[yY][eE][sS])$ ]]; then
  info "Installation aborted by user. Exiting."
  exit 0
fi

# Ask for VNC password (or auto-generate)
read -r -p "Enter VNC password to set for Kali (6-16 chars) [leave empty to auto-generate]: " VNC_PASS
if [ -z "${VNC_PASS}" ]; then
  if command -v openssl >/dev/null 2>&1; then
    VNC_PASS=$(openssl rand -hex 5) # 10 hex chars ~ decent for lab
  else
    VNC_PASS=$(date +%s | sha256sum | head -c 10)
  fi
  info "Auto-generated VNC password: $VNC_PASS"
else
  info "Using provided VNC password (hidden)."
fi

# Prepare directories
mkdir -p "$INSTALL_DIR"
mkdir -p "$START_DIR"

# Install prerequisites
info "Updating Termux packages and installing prerequisites..."
pkg update -y || warn "pkg update failed; continuing"
pkg upgrade -y || warn "pkg upgrade failed; continuing"
pkg install -y proot-distro pulseaudio tigervnc openssh curl wget proot pulseaudio-utils termux-exec git python openssl || true

if ! command -v proot-distro >/dev/null 2>&1; then
  err "proot-distro not available. Run this in Termux with network access."
fi

# Install Kali if missing
if proot-distro list | grep -qi "$DIST_NAME"; then
  info "Kali distro '$DIST_NAME' already registered."
else
  info "Installing Kali rootfs via proot-distro (may download many MBs/GBs). Be patient..."
  proot-distro install "$DIST_NAME" || err "proot-distro install failed. Check storage/network."
fi

# Create bootstrap for Kali
info "Preparing Kali bootstrap script..."
cat > "$BOOTSTRAP" <<'EO_BOOT'
#!/usr/bin/env bash
set -e
export DEBIAN_FRONTEND=noninteractive
apt update -y || true
apt upgrade -y || true
apt install -y xfce4 xfce4-goodies dbus-x11 tigervnc-standalone-server tigervnc-common sudo x11-utils xterm wget nano || true
# Create user
if ! id -u termuxuser >/dev/null 2>&1; then
  useradd -m -s /bin/bash termuxuser || true
  echo "termuxuser:termux" | chpasswd || true
  usermod -aG sudo termuxuser || true
fi
# Setup xstartup
USER_HOME=/home/termuxuser
mkdir -p $USER_HOME/.vnc
cat > $USER_HOME/.vnc/xstartup <<'XSU'
#!/bin/sh
[ -x /etc/X11/Xsession ] && exec /etc/X11/Xsession
startxfce4 &
XSU
chown -R termuxuser:termuxuser $USER_HOME/.vnc || true
chmod +x $USER_HOME/.vnc/xstartup || true
apt autoremove -y || true
apt clean || true
echo "BOOTSTRAP_DONE"
EO_BOOT

chmod +x "$BOOTSTRAP"

# Run bootstrap inside Kali
info "Running bootstrap inside Kali (this can take a while)..."
proot-distro login "$DIST_NAME" -- bash -s < "$BOOTSTRAP" || warn "Bootstrap completed with warnings."

# Ensure ownership
proot-distro login "$DIST_NAME" -- bash -lc "chown -R termuxuser:termuxuser /home/termuxuser || true"

# Set VNC password inside Kali for termuxuser
info "Setting VNC password inside Kali for user 'termuxuser'..."
# We pass the VNC_PASS in an environment variable to the inner shell; use printf to feed vncpasswd
# Note: vncpasswd writes binary file to /home/termuxuser/.vnc/passwd
proot-distro login "$DIST_NAME" -- bash -lc "export VNC_PASS='${VNC_PASS}'; mkdir -p /home/termuxuser/.vnc; printf '%s\n%s\n' \"\$VNC_PASS\" \"\$VNC_PASS\" | sudo -u termuxuser vncpasswd -f > /home/termuxuser/.vnc/passwd && chmod 600 /home/termuxuser/.vnc/passwd && chown termuxuser:termuxuser /home/termuxuser/.vnc/passwd || true"
# Note: 'vncpasswd -f' writes the hashed password to stdout; we redirected it to the passwd file.

# Determine geometry
GEOM=$(detect_geometry)
info "Using VNC geometry: $GEOM"

# Create start/stop scripts (use password)
info "Creating start/stop helper scripts..."
cat > "$START_DIR/start-kali.sh" <<EO_START
#!/usr/bin/env bash
pulseaudio --start --exit-idle-time=-1 >/dev/null 2>&1 || true
# Start VNC server inside Kali as termuxuser with password already set
proot-distro login "$DIST_NAME" -- bash -lc "export HOME=/home/termuxuser; sudo -u termuxuser sh -c 'vncserver $VNC_DISPLAY -geometry $GEOM -depth 24 -localhost no || true' "
echo "Started Kali VNC on display $VNC_DISPLAY (port $VNC_PORT)"
EO_START
chmod +x "$START_DIR/start-kali.sh"

cat > "$START_DIR/stop-kali.sh" <<'EO_STOP'
#!/usr/bin/env bash
proot-distro login "'"$DIST_NAME"'" -- bash -lc "sudo -u termuxuser sh -c 'vncserver -kill :1 || true' "
pulseaudio --kill >/dev/null 2>&1 || true
echo "Stopped Kali VNC (if running)"
EO_STOP
chmod +x "$START_DIR/stop-kali.sh"

# Add aliases to rc files
info "Adding aliases to shell rc files..."
alias_line1="alias start-kali=\"$START_DIR/start-kali.sh\""
alias_line2="alias stop-kali=\"$START_DIR/stop-kali.sh\""
grep -qxF "$alias_line1" ~/.bashrc 2>/dev/null || echo "$alias_line1" >> ~/.bashrc
grep -qxF "$alias_line2" ~/.bashrc 2>/dev/null || echo "$alias_line2" >> ~/.bashrc
if [ -f ~/.zshrc ]; then
  grep -qxF "$alias_line1" ~/.zshrc 2>/dev/null || echo "$alias_line1" >> ~/.zshrc
  grep -qxF "$alias_line2" ~/.zshrc 2>/dev/null || echo "$alias_line2" >> ~/.zshrc
fi

# Auto-start GUI now
info "Auto-starting Kali GUI now..."
bash "$START_DIR/start-kali.sh" || warn "start-kali reported warnings"
sleep 4

# Detect host IP for user convenience
HOST_IP=$(detect_host_ip)
if [ -z "$HOST_IP" ]; then HOST_IP="127.0.0.1"; fi
VNC_URI="vnc://${HOST_IP}:${VNC_PORT}"
# Try including password in URI (some clients accept user:pass@host)
VNC_URI_WITH_PASS="vnc://:$(python3 -c 'import sys,urllib.parse as u; print(u.quote(sys.argv[1]))' "$VNC_PASS")@${HOST_IP}:${VNC_PORT}"

info "VNC connection: $HOST_IP:$VNC_PORT (password set)"

# Auto-launch bVNC if installed, otherwise open Play Store
info "Checking for bVNC..."
BVNC_INSTALLED=0
if command -v pm >/dev/null 2>&1; then
  if pm list packages | grep -qi "$BVNC_PKG"; then
    BVNC_INSTALLED=1
  fi
fi

if [ $BVNC_INSTALLED -eq 1 ]; then
  info "bVNC installed — attempting to open connection..."
  # Try to open URI with password; fallback to URI without password if that fails
  if command -v am >/dev/null 2>&1; then
    am start -a android.intent.action.VIEW -d "$VNC_URI_WITH_PASS" >/dev/null 2>&1 || am start -a android.intent.action.VIEW -d "$VNC_URI" >/dev/null 2>&1 || warn "Unable to auto-open bVNC; please open bVNC and connect to $VNC_URI"
  else
    info "Cannot auto-open bVNC (no am). Please open bVNC and connect to: $VNC_URI"
  fi
else
  info "bVNC not installed. Opening Play Store so you can install bVNC."
  if command -v am >/dev/null 2>&1; then
    am start -a android.intent.action.VIEW -d "$BVNC_MARKET_URI" >/dev/null 2>&1 || am start -a android.intent.action.VIEW -d "$BVNC_WEB_URL" >/dev/null 2>&1 || warn "Unable to open Play Store; please install bVNC from: $BVNC_WEB_URL"
  elif command -v termux-open-url >/dev/null 2>&1; then
    termux-open-url "$BVNC_WEB_URL" >/dev/null 2>&1 || warn "termux-open-url failed; open $BVNC_WEB_URL manually"
  else
    warn "Cannot open Play Store automatically. Install bVNC and connect to: $VNC_URI"
  fi
fi

# Final summary
cat <<EOF

SUCCESS ✅
  VNC host: ${HOST_IP}
  VNC port: ${VNC_PORT}
  Display: ${VNC_DISPLAY}
  Geometry: ${GEOM}
  VNC password: (the password you provided / auto-generated)
    -> note: password was set inside the Kali user as specified during install.

Connections:
  - Recommended: open bVNC (auto-open attempted). If it failed, install bVNC or open it manually.
  - VNC URI (with encoded password): ${VNC_URI_WITH_PASS}
  - VNC URI (no password): ${VNC_URI}

Convenience:
  - start-kali : starts VNC (if stopped)
  - stop-kali  : stops VNC

Security note:
  - Using a password and removing '-SecurityTypes None' makes the session password protected.
  - Do NOT expose VNC port publicly without additional protections (SSH tunnel, VPN).

Troubleshooting:
  - If VNC client cannot connect immediately, wait ~10s and try again.
  - View logs:
      proot-distro login ${DIST_NAME} -- bash -lc "ls -la /home/termuxuser/.vnc; tail -n 200 /home/termuxuser/.vnc/*.log"

EOF

info "HCO Kali Termux by Azhar — GUI Ready!"
