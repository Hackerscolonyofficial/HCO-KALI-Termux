#!/usr/bin/env bash
# HCO-KALI-Termux.sh — Full installer with real VNC server + auto-launch RealVNC
# Author: Azhar | Hackers Colony
# Usage: chmod +x HCO-KALI-Termux.sh && ./HCO-KALI-Termux.sh

set -euo pipefail
DEBUG=0    # set to 1 for extra debug output

# ---------- Config ----------
YOUTUBE_URL="https://youtube.com/@hackers_colony_tech?si=pvdCWZggTIuGb0ya"
PREFERRED="kali"
FALLBACK="debian"
BOOTSTRAP_FLAG="${HOME}/.hco_kali_bootstrap_done"
PREFIX="${PREFIX:-/data/data/com.termux/files/usr}"
DIST_USER="termuxuser"

VNC_PASS_FILE="${HOME}/.vncpass"   # saved generated password
VNC_PORT_FILE="${HOME}/.vncport"   # saved chosen port
DEFAULT_GEOM="1280x720"
DISPLAY_NUM=":1"                   # X display used inside distro (kept constant)

# ---------- Helpers ----------
info(){ printf "\e[1;36m[INFO]\e[0m %s\n" "$*"; }
warn(){ printf "\e[1;33m[WARN]\e[0m %s\n" "$*"; }
err(){ printf "\e[1;31m[ERR]\e[0m %s\n" "$*"; exit 1; }
detect_arch(){ uname -m 2>/dev/null || echo "unknown"; }

port_is_free() {
  local p=$1
  if command -v ss >/dev/null 2>&1; then
    ! ss -ltn 2>/dev/null | awk '{print $4}' | grep -qE "(:|\\.)${p}\$"
    return
  elif command -v netstat >/dev/null 2>&1; then
    ! netstat -tln 2>/dev/null | awk '{print $4}' | grep -qE "(:|\\.)${p}\$"
    return
  else
    # fallback: try to bind with nc if available
    if command -v nc >/dev/null 2>&1; then
      (nc -l 127.0.0.1 "$p" >/dev/null 2>&1 & sleep 0.3; kill $! >/dev/null 2>&1) 2>/dev/null
      return $?
    fi
    # assume free if we can't check
    return 0
  fi
}

choose_free_port() {
  local start=5901
  local max=5910
  for ((p=start;p<=max;p++)); do
    if port_is_free "$p"; then
      printf "%s" "$p"
      return 0
    fi
  done
  # fallback
  printf "5901"
  return 0
}

get_host_ip(){
  # try common interfaces
  local ip
  ip=$(ip addr show wlan0 2>/dev/null | awk '/inet /{print $2; exit}' | cut -d/ -f1)
  [ -z "$ip" ] && ip=$(ip addr show eth0 2>/dev/null | awk '/inet /{print $2; exit}' | cut -d/ -f1)
  [ -z "$ip" ] && ip=$(ip addr show rmnet_data0 2>/dev/null | awk '/inet /{print $2; exit}' | cut -d/ -f1)
  [ -z "$ip" ] && ip="127.0.0.1"
  printf "%s" "$ip"
}

# ---------- YouTube lock/countdown (kept) ----------
clear
echo -e "\e[1;33m🔒 TOOL LOCKED — HCO-KALI-Termux\e[0m"
echo "To continue please subscribe to Hackers Colony Tech on YouTube and click the bell."
echo -n "Redirecting to YouTube in "
for i in {9..1}; do
  printf "\e[38;5;$((160 + (i*2) % 80))m%s \e[0m" "$i"
  sleep 1
done
echo
if command -v termux-open-url >/dev/null 2>&1; then
  termux-open-url "$YOUTUBE_URL" >/dev/null 2>&1 || true
elif command -v am >/dev/null 2>&1; then
  am start -a android.intent.action.VIEW -d "$YOUTUBE_URL" >/dev/null 2>&1 || true
else
  echo "Open this URL manually: $YOUTUBE_URL"
fi
read -r -p $'\nPress ENTER when you are back in Termux to continue: '

# ---------- Ensure Termux prerequisites ----------
info "Installing required Termux packages (proot-distro etc)..."
pkg update -y >/dev/null || warn "pkg update failed (continuing)"
pkg install -y proot-distro wget curl coreutils util-linux openssh git x11-repo || true
# install 'ss' provider and other useful tools
pkg install -y iproute2 busybox-nettools || true

command -v proot-distro >/dev/null 2>&1 || err "proot-distro not installed. Install Termux (F-Droid) and retry."

# ---------- Create proot-distro profile if missing ----------
if ! proot-distro list | grep -Eqi "^(${PREFERRED}|${FALLBACK})"; then
  info "No distro profile found — creating Kali profile (if compatible)..."
  mkdir -p "${PREFIX}/etc/proot-distro"
  arch=$(detect_arch)
  case "$arch" in
    aarch64|arm64)
      TARBALL_URL="https://images.offensive-security.com/arm-images/kali-raspberrypi/kali-linux-raspberrypi-2023.5-arm64.tar.xz"
      ;;
    armv7l|arm*)
      TARBALL_URL="https://images.offensive-security.com/arm-images/kali-raspberrypi/kali-linux-raspberrypi-2023.5-armhf.tar.xz"
      ;;
    *)
      TARBALL_URL=""
      ;;
  esac
  if [ -n "$TARBALL_URL" ]; then
    cat > "${PREFIX}/etc/proot-distro/${PREFERRED}.sh" <<EOF
DISTRO_NAME="Kali Linux (HCO profile)"
DISTRO_COMMENT="Kali Linux custom profile"
TARBALL_URL="${TARBALL_URL}"
TARBALL_SHA256=""
EOF
    info "Created ${PREFIX}/etc/proot-distro/${PREFERRED}.sh"
  else
    warn "No suitable Kali tarball for arch ${arch}; will rely on default proot-distro list."
  fi
fi

# ---------- Install distro (non-interactive) ----------
DIST="$PREFERRED"
info "Installing distro ${DIST} (non-interactive)... This may take several minutes."
set +e
echo "y" | proot-distro install "$DIST" >/dev/null 2>&1
rc=$?
set -e
if [ $rc -ne 0 ]; then
  warn "Install for ${DIST} failed — trying fallback ${FALLBACK}..."
  DIST="$FALLBACK"
  echo "y" | proot-distro install "$DIST" >/dev/null 2>&1 || err "Failed to install fallback distro ${FALLBACK}."
fi
info "Using distro: ${DIST}"

# ---------- Bootstrap inside distro (install Xvfb/x11vnc/tightvnc & create user) ----------
if [ ! -f "$BOOTSTRAP_FLAG" ]; then
  info "Bootstrapping Xvfb, x11vnc and tools inside distro (this may take a while)..."
  TMP_SCRIPT=$(mktemp)
  cat > "$TMP_SCRIPT" <<'EOBOOT'
#!/usr/bin/env bash
set -e
export DEBIAN_FRONTEND=noninteractive
apt update -y || true
apt upgrade -y || true

# install lightweight desktop + VNC utilities
apt install -y xfce4 xfce4-terminal xfdesktop dbus-x11 x11-xkb-utils x11-utils xterm nano wget curl xvfb x11vnc tightvncserver || true

# create user termuxuser if missing
if ! id -u termuxuser >/dev/null 2>&1; then
  useradd -m -s /bin/bash termuxuser || true
fi

# create .xsession to start xfce
USER_HOME=/home/termuxuser
mkdir -p ${USER_HOME}
cat > ${USER_HOME}/.xsession <<'XSE'
#!/bin/sh
export LANG=C
exec startxfce4
XSE
chmod +x ${USER_HOME}/.xsession || true
chown -R termuxuser:termuxuser ${USER_HOME} 2>/dev/null || true

echo "BOOTSTRAP_DONE"
EOBOOT

  proot-distro login "$DIST" -- bash -s < "$TMP_SCRIPT" || warn "Bootstrap inside distro completed with warnings."
  rm -f "$TMP_SCRIPT"
  touch "$BOOTSTRAP_FLAG"
  info "Bootstrap finished."
else
  info "Bootstrap already completed."
fi

# ---------- choose free port ----------
if [ -f "$VNC_PORT_FILE" ]; then
  PORT=$(cat "$VNC_PORT_FILE")
  info "Using previously saved VNC port: $PORT"
else
  PORT=$(choose_free_port)
  echo "$PORT" > "$VNC_PORT_FILE"
  info "Chosen VNC port: $PORT (saved to $VNC_PORT_FILE)"
fi

# ---------- prepare or reuse password ----------
if [ -f "$VNC_PASS_FILE" ]; then
  PASS="$(cat "$VNC_PASS_FILE")"
  info "Using existing saved VNC password (from $VNC_PASS_FILE)."
else
  PASS="$(tr -dc A-Za-z0-9 </dev/urandom | head -c 12)"
  echo "$PASS" > "$VNC_PASS_FILE"
  chmod 600 "$VNC_PASS_FILE"
  info "Generated VNC password and saved to $VNC_PASS_FILE"
fi

# ---------- start Xvfb + x11vnc inside distro ----------
info "Starting Xvfb and x11vnc inside distro (display ${DISPLAY_NUM}, port ${PORT})..."
proot-distro login "$DIST" -- bash -lc "set -e
# ensure home dir
mkdir -p /home/${DIST_USER}/.vnc
chown -R ${DIST_USER}:${DIST_USER} /home/${DIST_USER} 2>/dev/null || true

# write passwd using vncpasswd (tightvncserver) - non-interactive
printf '%s\n%s\n' \"${PASS}\" \"${PASS}\" | vncpasswd -f > /home/${DIST_USER}/.vnc/passwd 2>/dev/null || true

# fallback to x11vnc -storepasswd if file not created
if [ ! -s /home/${DIST_USER}/.vnc/passwd ]; then
  printf '%s\n' \"${PASS}\" | x11vnc -storepasswd -f /home/${DIST_USER}/.vnc/passwd 2>/dev/null || true
fi

chmod 600 /home/${DIST_USER}/.vnc/passwd || true
chown -R ${DIST_USER}:${DIST_USER} /home/${DIST_USER}/.vnc 2>/dev/null || true

# start Xvfb and wait
Xvfb ${DISPLAY_NUM} -screen 0 ${DEFAULT_GEOM} -ac >/home/${DIST_USER}/.vnc/xvfb.log 2>&1 &
sleep 2

# start x11vnc binding to 0.0.0.0 (so host can reach it)
x11vnc -display ${DISPLAY_NUM} -rfbport ${PORT} -rfbauth /home/${DIST_USER}/.vnc/passwd -forever -shared -bg -noxdamage >/home/${DIST_USER}/.vnc/x11vnc.log 2>&1 || true

echo 'VNC_STARTED'
"

# small wait and check inside distro
sleep 2
if proot-distro login "$DIST" -- bash -lc "pgrep -a x11vnc >/dev/null 2>&1"; then
  info "x11vnc appears to be running inside distro."
else
  warn "x11vnc not detected running. See logs: proot-distro login $DIST -- bash -lc 'tail -n +1 /home/${DIST_USER}/.vnc/x11vnc.log'"
  err "VNC server failed to start."
fi

# ---------- detect host ip and build vnc url ----------
HOST_IP="$(get_host_ip)"
VNC_URL="vnc://${HOST_IP}:${PORT}"

info "VNC server is running!"
info "Connect with any VNC client to: ${HOST_IP}:${PORT}"
info "Password: ${PASS}"

# ---------- try to auto-open RealVNC (vnc://) ----------
info "Attempting to open RealVNC (or default VNC handler) on Android..."

if command -v am >/dev/null 2>&1; then
  # android intent open
  am start -a android.intent.action.VIEW -d "${VNC_URL}" >/dev/null 2>&1 && info "Opened VNC viewer via Android intent." || warn "Could not open VNC viewer via intent; open ${VNC_URL} manually."
elif command -v termux-open-url >/dev/null 2>&1; then
  termux-open-url "${VNC_URL}" >/dev/null 2>&1 && info "Opened VNC viewer via termux-open-url." || warn "Could not open VNC viewer; open ${VNC_URL} manually."
else
  warn "No method to auto-open VNC viewer; open ${VNC_URL} manually."
fi

# ---------- final instructions ----------
echo
info "If the VNC client fails to connect:"
info "  1) Check VNC logs inside distro: proot-distro login ${DIST} -- bash -lc 'tail -n 200 /home/${DIST_USER}/.vnc/x11vnc.log'"
info "  2) Confirm Xvfb: proot-distro login ${DIST} -- bash -lc 'pgrep -a Xvfb; tail -n 50 /home/${DIST_USER}/.vnc/xvfb.log'"
info "  3) If passwd file missing: proot-distro login ${DIST} -- bash -lc 'vncpasswd -f' or 'x11vnc -storepasswd' interactively"
info "Done — HCO-KALI-Termux by Azhar"
