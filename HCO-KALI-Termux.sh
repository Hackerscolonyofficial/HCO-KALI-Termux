#!/usr/bin/env bash
# HCO-KALI-Termux.sh (updated) — full installer with RealVNC auto-start
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
VNC_PASS="termux"

# ---------- Helpers ----------
info(){ printf "\e[1;36m[INFO]\e[0m %s\n" "$*"; }
warn(){ printf "\e[1;33m[WARN]\e[0m %s\n" "$*"; }
err(){ printf "\e[1;31m[ERR]\e[0m %s\n" "$*"; exit 1; }

detect_arch(){ uname -m || echo "unknown"; }

# ---------- Unlock & YouTube redirect ----------
clear
echo -e "\e[1;33m🔒 TOOL LOCKED — HCO-KALI-Termux\e[0m"
echo "To continue please subscribe to Hackers Colony Tech on YouTube and click the bell."
echo -n "Redirecting to YouTube in "
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
  echo "Open this URL manually: $YOUTUBE_URL"
fi
read -r -p $'\nPress ENTER when you are back in Termux to continue: '

# ---------- Ensure prerequisites ----------
info "Updating packages and ensuring proot-distro is installed..."
pkg update -y || warn "pkg update failed (continue)"
pkg install -y proot-distro wget curl coreutils util-linux openssh git x11vnc xvfb xfce4 xfce4-terminal xfce4-panel xfdesktop x11-xkb-utils dbus-x11 sudo nano || true
if ! command -v proot-distro >/dev/null 2>&1; then
  err "proot-distro not available. Install Termux (from F-Droid) and ensure proot-distro package is installed."
fi

# ---------- Create Kali profile if missing ----------
if ! proot-distro list | grep -qi "^${PREFERRED}|^${FALLBACK}"; then
  info "No Kali/Debian profiles present. Creating Kali profile..."
  mkdir -p "${PREFIX}/etc/proot-distro" || true
  arch=$(detect_arch)
  case "$arch" in
    aarch64|arm64)
      TARBALL_URL="https://images.offensive-security.com/arm-images/kali-raspberrypi/kali-linux-raspberrypi-2023.5-arm64.tar.xz"
      ;;
    armv7l|arm*)
      TARBALL_URL="https://images.offensive-security.com/arm-images/kali-raspberrypi/kali-linux-raspberrypi-2023.5-armhf.tar.xz"
      ;;
    x86_64|amd64)
      TARBALL_URL=""
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
    info "Custom Kali profile created: ${PREFIX}/etc/proot-distro/${PREFERRED}.sh"
  else
    warn "No suitable Kali tarball for arch '$arch'. Will use Debian fallback."
  fi
fi

# ---------- Install distro ----------
info "Installing '${PREFERRED}' or fallback '${FALLBACK}'..."
rc=0
set +e
if proot-distro list | grep -qi "^${PREFERRED}"; then
  proot-distro install "${PREFERRED}" || rc=$?
else
  proot-distro install "${PREFERRED}" 2>/dev/null || rc=$?
fi
set -e

if [ "$rc" -ne 0 ]; then
  warn "Failed '${PREFERRED}', installing fallback '${FALLBACK}'..."
  if ! proot-distro list | grep -qi "^${FALLBACK}"; then
    proot-distro install "${FALLBACK}" || err "Failed fallback '${FALLBACK}'"
  fi
  DIST="${FALLBACK}"
else
  DIST="${PREFERRED}"
fi
info "Using distro: ${DIST}"

# ---------- Bootstrap XFCE ----------
if [ ! -f "${BOOTSTRAP_FLAG}" ]; then
  info "Bootstrapping XFCE..."
  tmpf=$(mktemp)
  cat > "${tmpf}" <<'EOBOOT'
#!/usr/bin/env bash
set -e
export DEBIAN_FRONTEND=noninteractive
apt update -y || true
apt upgrade -y || true
apt install -y xfce4 xfce4-terminal xfce4-panel xfdesktop dbus-x11 x11-utils x11-xkb-utils x11vnc xvfb sudo nano || true
if ! id -u termuxuser >/dev/null 2>&1; then
  useradd -m -s /bin/bash termuxuser || true
  echo "termuxuser:termux" | chpasswd || true
  usermod -aG sudo termuxuser || true
fi
USER_HOME=/home/termuxuser
mkdir -p ${USER_HOME}
cat > ${USER_HOME}/.xsession <<'XSE'
#!/bin/sh
export LANG=C
exec startxfce4
XSE
chown -R termuxuser:termuxuser ${USER_HOME} || true
chmod +x ${USER_HOME}/.xsession || true
echo "BOOTSTRAP_DONE"
EOBOOT
  proot-distro login "${DIST}" -- bash -s < "${tmpf}" || warn "Bootstrap finished with warnings"
  rm -f "${tmpf}"
  touch "${BOOTSTRAP_FLAG}"
  info "Bootstrap completed."
else
  info "Bootstrap already done."
fi

# ---------- Create start-xfce wrapper ----------
cat > "${START_XFCE}" <<'EOS'
#!/usr/bin/env bash
set -euo pipefail
DIST="debian"
DISPLAY=:0
export DISPLAY
proot-distro login "${DIST}" -- bash -lc "sudo -u termuxuser /home/termuxuser/.xsession > /dev/null 2>&1 & disown"
echo "[INFO] XFCE start command issued. Switch to VNC client or Termux:X11 if running."
EOS
chmod +x "${START_XFCE}"

# ---------- Create start-vnc wrapper ----------
cat > "${START_VNC}" <<'EOS'
#!/usr/bin/env bash
set -euo pipefail
DIST="debian"
PORT=5901
PASS="termux"
DISPLAY=:1

info(){ printf "\e[1;36m[INFO]\e[0m %s\n" "$*"; }
warn(){ printf "\e[1;33m[WARN]\e[0m %s\n" "$*"; }

info "Creating .vnc/passwd inside distro..."
proot-distro login "$DIST" -- bash -lc "
mkdir -p /home/termuxuser/.vnc
echo '$PASS' | vncpasswd -f > /home/termuxuser/.vnc/passwd
chmod 600 /home/termuxuser/.vnc/passwd
chown -R termuxuser:termuxuser /home/termuxuser || true
"

info "Killing previous VNC sessions..."
proot-distro login "$DIST" -- bash -lc "vncserver -kill :1 >/dev/null 2>&1 || true; pkill -f Xvfb || true; pkill -f x11vnc || true"

info "Starting Xvfb..."
proot-distro login "$DIST" -- bash -lc "Xvfb $DISPLAY -screen 0 1280x720x16 -ac >/home/termuxuser/.vnc/xvfb.log 2>&1 & echo \$! > /home/termuxuser/.vnc/xvfb.pid"

sleep 2
info "Starting x11vnc..."
proot-distro login "$DIST" -- bash -lc "x11vnc -display $DISPLAY -rfbport $PORT -rfbauth /home/termuxuser/.vnc/passwd -forever -shared -bg -o /home/termuxuser/.vnc/x11vnc.log || true"

sleep 2
HOST_IP=$(ip addr show wlan0 2>/dev/null | awk '/inet /{print $2; exit}' | cut -d/ -f1)
HOST_IP=${HOST_IP:-127.0.0.1}
info "VNC server running at: ${HOST_IP}:${PORT} (password: ${PASS})"

# Attempt to auto-launch RealVNC if installed
VNC_URL="vnc://${HOST_IP}:${PORT}"
if command -v am >/dev/null 2>&1; then
  am start -a android.intent.action.VIEW -d "${VNC_URL}" >/dev/null 2>&1 && info "Attempted to open VNC viewer."
else
  warn "Open a VNC client manually at ${VNC_URL}"
fi
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
