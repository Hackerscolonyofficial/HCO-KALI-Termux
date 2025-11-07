#!/usr/bin/env bash
# HCO-KALI-VNC-AUTO-MULTI.sh
# Auto-install & start real TightVNC server(s) inside proot-distro (Debian/Kali).
# - Bootstraps XFCE + tightvncserver inside distro (if needed)
# - Creates termuxuser if missing
# - Auto-generates & saves VNC password (~/.hco_vnc_pass)
# - Tries displays :1..:5, starts first free real vncserver (tightvnc)
# - Saves chosen display/port to ~/.hco_vnc_display ~/.hco_vnc_port
# - Attempts to open Android VNC viewer via vnc:// intent
# Usage: chmod +x HCO-KALI-VNC-AUTO-MULTI.sh && ./HCO-KALI-VNC-AUTO-MULTI.sh

set -euo pipefail

# ---------- User config ----------
PREFERRED="${PREFERRED:-kali}"
FALLBACK="${FALLBACK:-debian}"
DIST="${DIST:-$FALLBACK}"   # default to debian if not set/installed
DIST_USER="termuxuser"
BOOTSTRAP_FLAG="${HOME}/.hco_vnc_bootstrap_done"
PASS_FILE="${HOME}/.hco_vnc_pass"
DISPLAY_FILE="${HOME}/.hco_vnc_display"
PORT_FILE="${HOME}/.hco_vnc_port"
VNC_GEOM="${VNC_GEOM:-1280x720}"
VNC_DEPTH="${VNC_DEPTH:-24}"
MAX_DISPLAY=5    # try displays 1..MAX_DISPLAY

# ---------- helpers ----------
info(){ printf "\e[1;36m[INFO]\e[0m %s\n" "$*"; }
warn(){ printf "\e[1;33m[WARN]\e[0m %s\n" "$*"; }
err(){ printf "\e[1;31m[ERR]\e[0m %s\n" "$*"; exit 1; }

# ensure proot-distro exists
if ! command -v proot-distro >/dev/null 2>&1; then
  err "proot-distro not installed. Install Termux (F-Droid) and then: pkg install proot-distro"
fi

# ensure a distro exists; if preferred present use it, else fallback to fallback
if proot-distro list | grep -qi "^${PREFERRED}"; then
  DIST="$PREFERRED"
elif proot-distro list | grep -qi "^${FALLBACK}"; then
  DIST="$FALLBACK"
else
  info "No existing distro profile found. Attempting to create a Kali profile (if arch supports) and install fallback ${FALLBACK}."
  arch="$(uname -m 2>/dev/null || echo unknown)"
  if [ "$arch" = "aarch64" ] || [ "$arch" = "arm64" ]; then
    mkdir -p "${PREFIX:-/data/data/com.termux/files/usr}/etc/proot-distro"
    cat > "${PREFIX:-/data/data/com.termux/files/usr}/etc/proot-distro/${PREFERRED}.sh" <<EOF
DISTRO_NAME="Kali Linux (HCO profile)"
DISTRO_COMMENT="Kali profile for HCO"
TARBALL_URL="https://images.offensive-security.com/arm-images/kali-raspberrypi/kali-linux-raspberrypi-2023.5-arm64.tar.xz"
TARBALL_SHA256=""
EOF
    info "Created ${PREFIX}/etc/proot-distro/${PREFERRED}.sh (if suitable)."
  fi
  info "Installing fallback distro: ${FALLBACK} (this may take several minutes)..."
  proot-distro install "$FALLBACK" || err "Failed to install ${FALLBACK}. Check storage/network."
  DIST="$FALLBACK"
fi

info "Using distro: $DIST"

# ---------- Bootstrap inside distro (install XFCE + tightvncserver) ----------
if [ ! -f "$BOOTSTRAP_FLAG" ]; then
  info "Bootstrapping XFCE + tightvncserver inside ${DIST} (this may take a while)..."
  TMP=$(mktemp)
  cat > "$TMP" <<'EOBOOT'
#!/usr/bin/env bash
set -e
export DEBIAN_FRONTEND=noninteractive

apt update -y || true
apt upgrade -y || true

# Install minimal XFCE and TightVNC (real VNC server)
apt install -y xfce4 xfce4-goodies tightvncserver sudo nano dbus-x11 x11-xkb-utils x11-utils || true

# Create termuxuser if missing
if ! id termuxuser >/dev/null 2>&1; then
  useradd -m -s /bin/bash termuxuser || true
  echo "termuxuser:termux" | chpasswd || true
  usermod -aG sudo termuxuser || true
fi

# Prepare XFCE startup for VNC sessions
USER_HOME=/home/termuxuser
mkdir -p ${USER_HOME}/.vnc
cat > ${USER_HOME}/.vnc/xstartup <<'XSU'
#!/bin/sh
xrdb $HOME/.Xresources
startxfce4 &
XSU
chmod +x ${USER_HOME}/.vnc/xstartup
chown -R termuxuser:termuxuser ${USER_HOME} 2>/dev/null || true

echo "BOOTSTRAP_DONE"
EOBOOT

  proot-distro login "$DIST" -- bash -s < "$TMP" || warn "Bootstrap finished with warnings."
  rm -f "$TMP"
  touch "$BOOTSTRAP_FLAG"
  info "Bootstrap completed."
else
  info "Bootstrap already completed."
fi

# ---------- ensure host-side saved password ----------
if [ ! -f "$PASS_FILE" ]; then
  info "Generating a secure VNC password and saving locally to $PASS_FILE"
  PASS="$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 16)"
  echo "$PASS" > "$PASS_FILE"
  chmod 600 "$PASS_FILE"
else
  PASS="$(cat "$PASS_FILE")"
fi

# ---------- create passwd inside distro (for TERMUXUSER) ----------
info "Writing VNC password inside distro for user ${DIST_USER}..."
# We'll write the password file inside the distro (non-interactive). password contains only alnum so safe to embed.
TMP_PASS_SCRIPT=$(mktemp)
cat > "$TMP_PASS_SCRIPT" <<EOF
#!/usr/bin/env bash
set -e
USER_HOME=/home/${DIST_USER}
mkdir -p \$USER_HOME/.vnc
# Use vncpasswd -f to write password file (tightvncserver provides vncpasswd)
printf '%s\n%s\n' '${PASS}' '${PASS}' | vncpasswd -f > \$USER_HOME/.vnc/passwd 2>/dev/null || true
# Fallback: try tightvncserver way (some distros)
if [ ! -s \$USER_HOME/.vnc/passwd ]; then
  printf '%s\n' '${PASS}' | x11vnc -storepasswd -f \$USER_HOME/.vnc/passwd 2>/dev/null || true
fi
chmod 600 \$USER_HOME/.vnc/passwd || true
chown -R ${DIST_USER}:${DIST_USER} \$USER_HOME 2>/dev/null || true
echo "PASSFILE_OK"
EOF

proot-distro login "$DIST" -- bash -s < "$TMP_PASS_SCRIPT" || warn "Password write inside distro returned warnings."
rm -f "$TMP_PASS_SCRIPT"

# ---------- try to start a real vncserver on :1..:MAX_DISPLAY ----------
info "Trying to start TightVNC server on first free display (:1..:${MAX_DISPLAY})..."
SELECTED_DISPLAY=""
for d in $(seq 1 $MAX_DISPLAY); do
  info "Attempting display :$d ..."
  TMP_START=$(mktemp)
  cat > "$TMP_START" <<EOF
#!/usr/bin/env bash
set -e
USER_HOME=/home/${DIST_USER}
# ensure passwd exists
if [ ! -s \$USER_HOME/.vnc/passwd ]; then
  printf '%s\n%s\n' '${PASS}' '${PASS}' | vncpasswd -f > \$USER_HOME/.vnc/passwd 2>/dev/null || true
  chmod 600 \$USER_HOME/.vnc/passwd || true
  chown -R ${DIST_USER}:${DIST_USER} \$USER_HOME || true
fi
# kill existing on this display (ignore errors)
vncserver -kill :${d} >/dev/null 2>&1 || true
# try start as ${DIST_USER}
su - ${DIST_USER} -c "vncserver :${d} -geometry ${VNC_GEOM} -depth ${VNC_DEPTH}" >/tmp/hco_vnc_start_${d}.out 2>&1 || exit 2
echo "STARTED"
EOF

  # run the start attempt inside distro
  set +e
  proot-distro login "$DIST" -- bash -s < "$TMP_START"
  rc=$?
  set -e
  rm -f "$TMP_START"
  # check if started by reading vncserver processes
  if proot-distro login "$DIST" -- bash -lc "pgrep -af vncserver | grep -q \":${d}\" >/dev/null 2>&1"; then
    SELECTED_DISPLAY="$d"
    info "Successfully started real VNC server on display :$d"
    break
  else
    warn "Display :$d did not start (rc=$rc). Trying next."
    # continue loop
  fi
done

if [ -z "$SELECTED_DISPLAY" ]; then
  err "Could not start TightVNC server on any display 1..${MAX_DISPLAY}. Check logs inside the distro (/home/${DIST_USER}/.vnc/)."
fi

# ---------- save display & port info ----------
echo "${SELECTED_DISPLAY}" > "$DISPLAY_FILE"
PORT=$((5900 + SELECTED_DISPLAY))
echo "${PORT}" > "$PORT_FILE"
info "VNC display :${SELECTED_DISPLAY} -> port ${PORT} saved to $DISPLAY_FILE and $PORT_FILE"

# ---------- print connection info ----------
# determine host IP (best-effort)
HOST_IP="$(ip addr show wlan0 2>/dev/null | awk '/inet /{print $2; exit}' | cut -d/ -f1)"
if [ -z "$HOST_IP" ]; then
  # fallback common interfaces
  HOST_IP="$(ip addr show rmnet_data0 2>/dev/null | awk '/inet /{print $2; exit}' | cut -d/ -f1)"
fi
HOST_IP="${HOST_IP:-127.0.0.1}"
info "Real VNC server is running."
echo
echo "Connect with any VNC client (Real VNC / TightVNC / bVNC etc.):"
echo "Host: ${HOST_IP}"
echo "Port: ${PORT}"
echo "Display: :${SELECTED_DISPLAY}"
echo "Password: ${PASS}"
echo

# ---------- attempt to auto-open Android VNC viewer (if available) ----------
info "Attempting to open Android VNC viewer via vnc:// intent (if installed)..."
VNC_URL="vnc://${HOST_IP}:${PORT}"
# prefer termux-open-url then am
if command -v termux-open-url >/dev/null 2>&1; then
  termux-open-url "${VNC_URL}" >/dev/null 2>&1 && info "Tried termux-open-url -> ${VNC_URL}" || warn "termux-open-url failed."
elif command -v am >/dev/null 2>&1; then
  # use Android intent
  am start -a android.intent.action.VIEW -d "${VNC_URL}" >/dev/null 2>&1 && info "Tried Android intent -> ${VNC_URL}" || warn "Android intent failed."
else
  warn "No method to auto-open VNC viewer. Launch your VNC client and connect to ${HOST_IP}:${PORT}"
fi

info "Saved password -> $PASS_FILE, display -> $DISPLAY_FILE, port -> $PORT_FILE"
info "If client fails to connect, inspect logs inside distro: proot-distro login ${DIST} -- bash -lc 'ls -la /home/${DIST_USER}/.vnc; tail -n 200 /home/${DIST_USER}/.vnc/*.log'"
