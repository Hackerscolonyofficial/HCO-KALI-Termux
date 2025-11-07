#!/usr/bin/env bash
# HCO-KALI-Termux.sh — single-file installer (no-root)
# Author: Azhar | Hackers Colony
# Description:
#  - Shows a 🔒 unlock message and redirects to YouTube (subscribe & click bell),
#  - Displays "HCO Kali Termux by Azhar" in bold green inside a red bar,
#  - Installs Kali (proot-distro) in Termux, bootstraps XFCE + TigerVNC,
#  - Creates convenient start/stop helpers: start-kali / stop-kali.
#
# Usage: bash HCO-KALI-Termux.sh
set -euo pipefail

# -------------------------
# Config - edit if needed
# -------------------------
YOUTUBE_URL="https://youtube.com/@hackers_colony_tech?si=pvdCWZggTIuGb0ya"
DIST_NAME="kali-rolling"
HOME_DIR="${HOME:-/data/data/com.termux/files/home}"
INSTALL_DIR="$HOME_DIR/hco_kali_termux"
BOOTSTRAP="$INSTALL_DIR/bootstrap_kali.sh"
START_DIR="$HOME_DIR/kali-termux"
LOGPREFIX="[HCO-KALI-Termux]"

# ANSI colors
RED_BG="\033[41m"
GREEN_BOLD="\033[1;32m"
BOLD="\033[1m"
RESET="\033[0m"
YELLOW="\033[1;33m"
CYAN="\033[1;36m"
MAG="\033[1;35m"

info(){ printf "%b %s\\n" "$LOGPREFIX" "$*"; }
warn(){ printf "%b %s\\n" "$LOGPREFIX" "$*"; }
err(){ printf "%b %s\\n" "$LOGPREFIX" "$*"; exit 1; }

# -------------------------
# Unlock flow (subscribe +
# redirect to YouTube)
# -------------------------
clear
printf "%b\n\n" "${BOLD}🔒 TOOL LOCKED — HCO-KALI-Termux${RESET}"
printf "To unlock this tool and continue you must:\n"
printf "  1) Subscribe to the Hackers Colony Tech YouTube channel\n"
printf "  2) Click the bell icon to support the channel\n\n"
printf "%b\n" "${YELLOW}Redirecting to YouTube app in...${RESET}"

# Colorful countdown 9->1 using different ANSI colors for style
colors=( "\033[1;31m" "\033[1;33m" "\033[1;32m" "\033[1;36m" "\033[1;35m" "\033[1;34m" \
         "\033[38;5;208m" "\033[38;5;202m" "\033[38;5;201m" )
count=9
while [ $count -ge 1 ]; do
  col="${colors[$(( (9-count) % ${#colors[@]} ))]}"
  printf "%b %s %b\r" "$col" "  $count  " "$RESET"
  sleep 1
  ((count--))
done
printf "\n\n"

# Try to open the YouTube URL in app (termux-open-url or am start)
OPENED=0
if command -v termux-open-url >/dev/null 2>&1; then
  termux-open-url "$YOUTUBE_URL" >/dev/null 2>&1 || true
  OPENED=1
fi

if [ $OPENED -eq 0 ]; then
  if command -v am >/dev/null 2>&1; then
    am start -a android.intent.action.VIEW -d "$YOUTUBE_URL" >/dev/null 2>&1 || true
    OPENED=1
  fi
fi

printf "%b\n" "${CYAN}Opened YouTube (if available). Please subscribe & click the bell. When done, return to Termux and press ENTER to continue.${RESET}"
read -r -p $'\nPress ENTER when you are back in Termux to proceed with installation: '

# -------------------------
# Show title in green inside red bar (no ascii art)
# -------------------------
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

# -------------------------
# Confirm to proceed
# -------------------------
read -r -p "Proceed to install Kali (no-root) inside Termux? [Y/n]: " PROCEED
PROCEED="${PROCEED:-Y}"
if [[ ! "$PROCEED" =~ ^([yY]|[yY][eE][sS])$ ]]; then
  info "Installation aborted by user. Exiting."
  exit 0
fi

# -------------------------
# Prepare directories
# -------------------------
mkdir -p "$INSTALL_DIR"
mkdir -p "$START_DIR"

# -------------------------
# Install Termux prerequisites
# -------------------------
info "Updating Termux packages and installing prerequisites..."
pkg update -y || warn "pkg update failed; continuing"
pkg upgrade -y || warn "pkg upgrade failed; continuing"
pkg install -y proot-distro pulseaudio tigervnc openssh curl wget proot pulseaudio-utils termux-exec git python || true

if ! command -v proot-distro >/dev/null 2>&1; then
  err "proot-distro not installed. Please ensure you run this in Termux and have network access."
fi

# -------------------------
# Install Kali rootfs (if missing)
# -------------------------
if proot-distro list | grep -qi "$DIST_NAME"; then
  info "Kali distro '$DIST_NAME' already registered in proot-distro."
else
  info "Installing Kali rootfs via proot-distro (may download multiple GB). Please be patient..."
  proot-distro install "$DIST_NAME" || err "proot-distro install failed. Check your connection and storage."
fi

# -------------------------
# Create bootstrap script that will run inside Kali
# -------------------------
info "Preparing Kali bootstrap script (inside distro)."
cat > "$BOOTSTRAP" <<'EO_BOOT'
#!/usr/bin/env bash
set -e
export DEBIAN_FRONTEND=noninteractive
apt update -y || true
apt upgrade -y || true

# Install lightweight XFCE + VNC and utilities
apt install -y xfce4 xfce4-goodies dbus-x11 tigervnc-standalone-server tigervnc-common sudo x11-utils xterm wget nano || true

# Create basic user 'termuxuser' if not exists
if ! id -u termuxuser >/dev/null 2>&1; then
  useradd -m -s /bin/bash termuxuser || true
  echo "termuxuser:termux" | chpasswd || true
  usermod -aG sudo termuxuser || true
fi

# Setup VNC xstartup for the user
USER_HOME=/home/termuxuser
mkdir -p $USER_HOME/.vnc
cat > $USER_HOME/.vnc/xstartup <<'XSU'
#!/bin/sh
# Start dbus and XFCE session
[ -x /etc/X11/Xsession ] && exec /etc/X11/Xsession
startxfce4 &
XSU
chown -R termuxuser:termuxuser $USER_HOME/.vnc || true
chmod +x $USER_HOME/.vnc/xstartup || true

# Optionally configure VNC password (disabled by default for quick connect in lab)
# To enable: run vncpasswd as termuxuser inside the distro and remove -SecurityTypes None flag.
apt autoremove -y || true
apt clean || true

echo "BOOTSTRAP_DONE"
EO_BOOT

chmod +x "$BOOTSTRAP"

# -------------------------
# Run bootstrap inside Kali
# -------------------------
info "Executing bootstrap inside Kali (this will take time)."
proot-distro login "$DIST_NAME" -- bash -s < "$BOOTSTRAP" || warn "Bootstrap executed with warnings."

# Ensure home directory ownership for termuxuser
proot-distro login "$DIST_NAME" -- bash -lc "chown -R termuxuser:termuxuser /home/termuxuser || true"

# -------------------------
# Create start/stop helper scripts
# -------------------------
info "Creating start/stop helper scripts in $START_DIR ..."
cat > "$START_DIR/start-kali.sh" <<'EO_START'
#!/usr/bin/env bash
# Start PulseAudio in Termux (for sound)
pulseaudio --start --exit-idle-time=-1 >/dev/null 2>&1 || true
# Start VNC server inside Kali for user 'termuxuser' on :1 (5901)
proot-distro login '"$DIST_NAME"' -- bash -lc "export HOME=/home/termuxuser; sudo -u termuxuser sh -c 'vncserver :1 -geometry 1280x720 -depth 24 -localhost no -SecurityTypes None || true' "
echo "Kali XFCE VNC should be on 127.0.0.1:5901 (display :1). Connect with a VNC client."
EO_START
chmod +x "$START_DIR/start-kali.sh"

cat > "$START_DIR/stop-kali.sh" <<'EO_STOP'
#!/usr/bin/env bash
# Stop VNC inside Kali and PulseAudio on Termux
proot-distro login '"$DIST_NAME"' -- bash -lc "sudo -u termuxuser sh -c 'vncserver -kill :1 || true' "
pulseaudio --kill >/dev/null 2>&1 || true
echo "Stopped Kali VNC (if it was running)."
EO_STOP
chmod +x "$START_DIR/stop-kali.sh"

# -------------------------
# Add aliases to shell rc files
# -------------------------
info "Adding aliases to ~/.bashrc and ~/.zshrc (if present)."
alias_line1="alias start-kali=\"$START_DIR/start-kali.sh\""
alias_line2="alias stop-kali=\"$START_DIR/stop-kali.sh\""
grep -qxF "$alias_line1" ~/.bashrc 2>/dev/null || echo "$alias_line1" >> ~/.bashrc
grep -qxF "$alias_line2" ~/.bashrc 2>/dev/null || echo "$alias_line2" >> ~/.bashrc
if [ -f ~/.zshrc ]; then
  grep -qxF "$alias_line1" ~/.zshrc 2>/dev/null || echo "$alias_line1" >> ~/.zshrc
  grep -qxF "$alias_line2" ~/.zshrc 2>/dev/null || echo "$alias_line2" >> ~/.zshrc
fi

# -------------------------
# Final messages & usage
# -------------------------
info "Installation complete."
cat <<EOF

Quick usage:
  1) Start Kali XFCE desktop:
       start-kali
     Connect your Android VNC client to: 127.0.0.1:5901 (display :1)
     Recommended VNC apps: bVNC, VNC Viewer.

  2) Stop Kali:
       stop-kali

Notes:
 - This setup uses 'vncserver :1 -SecurityTypes None' for easy lab connectivity by default.
   For security, set a VNC password inside the Kali user:
     proot-distro login $DIST_NAME -- bash -lc "sudo -u termuxuser /usr/bin/vncpasswd"
   Then edit $START_DIR/start-kali.sh to remove '-SecurityTypes None'.

 - If connection fails: wait a minute and check logs:
     proot-distro login $DIST_NAME -- bash -lc "ls -la /home/termuxuser/.vnc; tail -n 100 /home/termuxuser/.vnc/*.log"

 - If proot-distro install failed due to space, free storage or use external/SD storage.

EOF

info "You can now run: start-kali"
