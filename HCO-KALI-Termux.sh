#!/usr/bin/env bash
# HCO-KALI-Termux — real VNC version
# Author: Azhar | Hackers Colony
# Usage: chmod +x HCO-KALI-Termux.sh && ./HCO-KALI-Termux.sh

set -euo pipefail

# ---------- Config ----------
YOUTUBE_URL="https://youtube.com/@hackers_colony_tech?si=pvdCWZggTIuGb0ya"
PREFERRED="kali"
FALLBACK="debian"
BOOTSTRAP_FLAG="${HOME}/.hco_kali_bootstrap_done"
PREFIX="${PREFIX:-/data/data/com.termux/files/usr}"
START_VNC="${HOME}/start-vnc"
DEFAULT_VNC_PORT=5901
DEFAULT_VNC_PASS="termux"
VNC_PASS_FILE="${HOME}/.vncpass"
DIST="${DIST:-}"

info(){ printf "\e[1;36m[INFO]\e[0m %s\n" "$*"; }
warn(){ printf "\e[1;33m[WARN]\e[0m %s\n" "$*"; }
err(){ printf "\e[1;31m[ERR]\e[0m %s\n" "$*"; exit 1; }
detect_arch(){ uname -m || echo "unknown"; }

# ---------- YouTube redirect ----------
clear
echo -e "\e[1;33m🔒 TOOL LOCKED — HCO-KALI-Termux\e[0m"
echo "Subscribe to Hackers Colony Tech and click the bell."
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
    echo "Open manually: $YOUTUBE_URL"
fi
read -r -p $'\nPress ENTER when back in Termux to continue: '

# ---------- Ensure prerequisites ----------
info "Updating packages..."
pkg update -y || warn "pkg update failed"
pkg install -y proot-distro wget curl coreutils util-linux openssh git x11-repo || true
if ! command -v proot-distro >/dev/null 2>&1; then
    err "proot-distro not found. Install Termux from F-Droid and ensure proot-distro is installed."
fi

# ---------- Create Kali/Debian profile ----------
if ! proot-distro list | grep -qi "^${PREFERRED}\|^${FALLBACK}"; then
    info "No profiles found. Creating default profile..."
    mkdir -p "${PREFIX}/etc/proot-distro"
    arch=$(detect_arch)
    TARBALL_URL=""
    case "$arch" in
        aarch64|arm64)
            TARBALL_URL="https://images.offensive-security.com/arm-images/kali-raspberrypi/kali-linux-raspberrypi-2023.5-arm64.tar.xz"
            ;;
        armv7l|arm*)
            TARBALL_URL="https://images.offensive-security.com/arm-images/kali-raspberrypi/kali-linux-raspberrypi-2023.5-armhf.tar.xz"
            ;;
    esac
    if [ -n "$TARBALL_URL" ]; then
        cat > "${PREFIX}/etc/proot-distro/${PREFERRED}.sh" <<EOF
DISTRO_NAME="Kali Linux (HCO profile)"
DISTRO_COMMENT="Kali Linux custom profile (HCO)"
TARBALL_URL="${TARBALL_URL}"
TARBALL_SHA256=""
EOF
        info "Custom Kali profile created."
    else
        warn "No suitable Kali tarball. Using Debian fallback."
    fi
fi

# ---------- Install distro ----------
DIST=""
set +e
if proot-distro list | grep -qi "^${PREFERRED}"; then
    proot-distro install "${PREFERRED}"
    rc=$?
else
    proot-distro install "${PREFERRED}" 2>/dev/null
    rc=$?
fi
set -e
if [ "$rc" -ne 0 ]; then
    warn "Failed to install '${PREFERRED}', using fallback '${FALLBACK}'..."
    if ! proot-distro list | grep -qi "^${FALLBACK}"; then
        proot-distro install "${FALLBACK}" || err "Fallback install failed"
    fi
    DIST="${FALLBACK}"
else
    DIST="${PREFERRED}"
fi
info "Using distro: ${DIST}"

# ---------- Bootstrap VNC inside distro ----------
if [ ! -f "${BOOTSTRAP_FLAG}" ]; then
    info "Bootstrapping VNC inside ${DIST}..."
    tmpf=$(mktemp)
    cat > "${tmpf}" <<'EOBOOT'
#!/usr/bin/env bash
set -e
export DEBIAN_FRONTEND=noninteractive

apt update -y || true
apt upgrade -y || true
apt install -y xfce4 xfce4-terminal xfce4-panel xfdesktop dbus-x11 x11-utils xterm sudo nano tightvncserver || true

# Create termuxuser if missing
if ! id -u termuxuser >/dev/null 2>&1; then
    useradd -m -s /bin/bash termuxuser || true
    echo "termuxuser:termux" | chpasswd || true
    usermod -aG sudo termuxuser || true
fi

# Create .xsession
USER_HOME=/home/termuxuser
mkdir -p "${USER_HOME}"
cat > "${USER_HOME}/.xsession" <<'XSE'
#!/bin/sh
export LANG=C
exec startxfce4
XSE
chown -R termuxuser:termuxuser "${USER_HOME}" || true
chmod +x "${USER_HOME}/.xsession" || true

# Setup VNC password
su - termuxuser -c "mkdir -p ~/.vnc"
if [ ! -f /home/termuxuser/.vnc/passwd ]; then
    su - termuxuser -c "echo 'termux' | vncpasswd -f > ~/.vnc/passwd"
    su - termuxuser -c "chmod 600 ~/.vnc/passwd"
fi

echo "BOOTSTRAP_DONE"
EOBOOT
    proot-distro login "${DIST}" -- bash -s < "${tmpf}" || warn "Bootstrap finished with warnings"
    rm -f "${tmpf}"
    touch "${BOOTSTRAP_FLAG}"
    info "Bootstrap completed."
else
    info "Bootstrap already done."
fi

# ---------- Create start-vnc wrapper ----------
cat > "${START_VNC}" <<'EOS'
#!/usr/bin/env bash
set -euo pipefail
DIST="${DIST:-debian}"
PORT=5901
PASS="termux"

info(){ printf "\e[1;36m[INFO]\e[0m %s\n" "$*"; }

# Detect device IP
DEVICE_IP=$(ip addr show wlan0 2>/dev/null | grep 'inet ' | awk '{print $2}' | cut -d/ -f1)
DEVICE_IP=${DEVICE_IP:-127.0.0.1}

info "Starting VNC inside ${DIST}..."
proot-distro login "${DIST}" -- bash -c "
su - termuxuser -c '
vncserver :1 -geometry 1280x720 -depth 24
'"
info "VNC server started!"
info "Connect your VNC client to ${DEVICE_IP}:${PORT} with password '${PASS}'"
EOS
chmod +x "${START_VNC}" || true
info "start-vnc wrapper created."

# ---------- Prompt to start VNC ----------
read -r -p "Start VNC now? [y/N]: " ANSWER
ANSWER="${ANSWER:-N}"
if [[ "$ANSWER" =~ ^([yY][eE][sS]|[yY])$ ]]; then
    info "Auto-starting VNC..."
    bash "${START_VNC}"
else
    info "Setup finished. To start VNC later, run: ${START_VNC}"
fi

echo
info "Done — HCO-KALI-Termux by Azhar"
