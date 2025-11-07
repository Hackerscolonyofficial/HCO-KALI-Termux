#!/usr/bin/env bash
# HCO-KALI-Termux.sh — Full installer with RealVNC auto-start inside proot-distro
# Author: Azhar | Hackers Colony
set -euo pipefail

# ---------- Config ----------
YOUTUBE_URL="https://youtube.com/@hackers_colony_tech?si=pvdCWZggTIuGb0ya"
PREFERRED="kali"
FALLBACK="debian"
BOOTSTRAP_FLAG="${HOME}/.hco_kali_bootstrap_done"
PREFIX="${PREFIX:-/data/data/com.termux/files/usr}"
START_XFCE="${HOME}/start-xfce"
START_VNC="${HOME}/start-vnc"
DEFAULT_GEOM="1280x720"
VNC_PORT=5901
VNC_PASS="${HOME}/.hco_vnc_pass"

info(){ printf "\e[1;36m[INFO]\e[0m %s\n" "$*"; }
warn(){ printf "\e[1;33m[WARN]\e[0m %s\n" "$*"; }
err(){ printf "\e[1;31m[ERR]\e[0m %s\n" "$*"; exit 1; }

detect_arch(){ uname -m || echo "unknown"; }

# ---------- Unlock & YouTube redirect ----------
clear
echo -e "\e[1;33m🔒 TOOL LOCKED — HCO-KALI-Termux\e[0m"
echo "Subscribe to Hackers Colony Tech on YouTube to continue."
echo -n "Redirecting in "
for i in 9 8 7 6 5 4 3 2 1; do
  printf "\e[38;5;$((160 + (i*2) % 80))m%s \e[0m" "$i"
  sleep 1
done
echo
if command -v termux-open-url >/dev/null 2>&1; then
  termux-open-url "$YOUTUBE_URL" >/dev/null 2>&1 || true
elif command -v am >/dev/null 2>&1; then
  am start -a android.intent.action.VIEW -d "$YOUTUBE_URL" >/dev/null 2>&1 || true
else
  echo "Open manually: $YOUTUBE_URL"
fi
read -r -p $'\nPress ENTER when back in Termux to continue: '

# ---------- Install Termux packages ----------
info "Updating Termux packages and installing prerequisites..."
pkg update -y || warn "pkg update failed"
pkg install -y proot-distro wget curl git sudo nano || true
if ! command -v proot-distro >/dev/null 2>&1; then
  err "proot-distro not installed. Install from F-Droid Termux."
fi

# ---------- Create Kali profile if missing ----------
if ! proot-distro list | grep -qi "^${PREFERRED}|^${FALLBACK}"; then
  info "Creating Kali profile..."
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
DISTRO_COMMENT="Kali Linux custom profile (HCO)"
TARBALL_URL="${TARBALL_URL}"
TARBALL_SHA256=""
EOF
    info "Kali profile created."
  else
    warn "No Kali tarball for '$arch'. Will fallback to Debian."
  fi
fi

# ---------- Install distro ----------
info "Installing distro..."
DIST="${PREFERRED}"
set +e
proot-distro install "${DIST}" 2>/dev/null
rc=$?
set -e
if [ "$rc" -ne 0 ]; then
  warn "Failed '${PREFERRED}', using fallback '${FALLBACK}'"
  DIST="${FALLBACK}"
  proot-distro install "${DIST}" || err "Failed fallback distro."
fi
info "Using distro: $DIST"

# ---------- Bootstrap inside distro ----------
if [ ! -f "${BOOTSTRAP_FLAG}" ]; then
  info "Bootstrapping distro (XFCE + VNC) ..."
  tmpf=$(mktemp)
  cat > "${tmpf}" <<'EOBOOT'
#!/usr/bin/env bash
set -e
export DEBIAN_FRONTEND=noninteractive
apt update -y
apt upgrade -y
apt install -y xfce4 xfce4-terminal xfce4-panel xfdesktop dbus-x11 x11-utils x11-xkb-utils x11vnc xvfb sudo nano
# Create user
if ! id -u termuxuser >/dev/null 2>&1; then
  useradd -m -s /bin/bash termuxuser
  echo "termuxuser:termux" | chpasswd
  usermod -aG sudo termuxuser
fi
# XFCE session
USER_HOME=/home/termuxuser
mkdir -p ${USER_HOME}
cat > ${USER_HOME}/.xsession <<'XSE'
#!/bin/sh
export LANG=C
exec startxfce4
XSE
chown -R termuxuser:termuxuser ${USER_HOME}
chmod +x ${USER_HOME}/.xsession
echo "BOOTSTRAP_DONE"
EOBOOT
  proot-distro login "${DIST}" -- bash -s < "${tmpf}"
  rm -f "${tmpf}"
  touch "${BOOTSTRAP_FLAG}"
  info "Bootstrap done."
else
  info "Bootstrap already done."
fi

# ---------- start-xfce wrapper ----------
cat > "${START_XFCE}" <<'EOS'
#!/usr/bin/env bash
set -euo pipefail
DIST="debian"
DISPLAY=:0
export DISPLAY
proot-distro login "$DIST" -- bash -lc "sudo -u termuxuser /home/termuxuser/.xsession > /dev/null 2>&1 & disown"
echo "[INFO] XFCE start command issued."
EOS
chmod +x "${START_XFCE}"

# ---------- start-vnc wrapper ----------
cat > "${START_VNC}" <<'EOS'
#!/usr/bin/env bash
set -euo pipefail
DIST="debian"
PORT=5901
DISPLAY=:1
PASS_FILE="${HOME}/.hco_vnc_pass"
info(){ printf "\e[1;36m[INFO]\e[0m %s\n" "$*"; }

# Generate or reuse password
if [ ! -f "$PASS_FILE" ]; then
  PASS=$(head -c 12 /dev/urandom | base64 | tr -dc 'a-zA-Z0-9')
  echo "$PASS" > "$PASS_FILE"
  chmod 600 "$PASS_FILE"
else
  PASS=$(cat "$PASS_FILE")
fi

info "VNC password saved to $PASS_FILE"

# Ensure .vnc folder
proot-distro login "$DIST" -- bash -lc "mkdir -p /home/termuxuser/.vnc; chown -R termuxuser:termuxuser /home/termuxuser"

# Kill previous sessions
proot-distro login "$DIST" -- bash -lc "pkill -f Xvfb || true; pkill -f x11vnc || true"

# Start Xvfb
proot-distro login "$DIST" -- bash -lc "Xvfb $DISPLAY -screen 0 1280x720x16 -ac >/home/termuxuser/.vnc/xvfb.log 2>&1 & echo \$! > /home/termuxuser/.vnc/xvfb.pid"

sleep 2

# Start x11vnc
proot-distro login "$DIST" -- bash -lc "x11vnc -display $DISPLAY -rfbport $PORT -passwdfile /home/termuxuser/.hco_vnc_pass -forever -shared -bg -o /home/termuxuser/.vnc/x11vnc.log"

sleep 2
HOST_IP=$(ip addr show wlan0 2>/dev/null | awk '/inet /{print $2; exit}' | cut -d/ -f1)
HOST_IP=${HOST_IP:-127.0.0.1}
info "VNC server running at: ${HOST_IP}:${PORT} (password: $(cat ${HOME}/.hco_vnc_pass))"

EOS
chmod +x "${START_VNC}"

# ---------- Prompt to start VNC ----------
read -r -p $'\nStart VNC now? [y/N]: ' ANSWER
ANSWER="${ANSWER:-N}"
if [[ "$ANSWER" =~ ^([yY][eE][sS]|[yY])$ ]]; then
  info "Auto-starting VNC..."
  bash "${START_VNC}"
else
  info "You can start VNC later with: ${START_VNC}"
fi

info "HCO-KALI-Termux setup complete!"
