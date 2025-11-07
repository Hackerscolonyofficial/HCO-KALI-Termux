#!/usr/bin/env bash
# HCO-KALI-Termux.sh — Full installer with VNC auto-start (no sudo)
# Author: Azhar | Hackers Colony

set -euo pipefail

# ---------------- Config ----------------
YOUTUBE_URL="https://youtube.com/@hackers_colony_tech?si=pvdCWZggTIuGb0ya"
PREFERRED="kali"
FALLBACK="debian"
BOOTSTRAP_FLAG="${HOME}/.hco_kali_bootstrap_done"
START_WRAPPER="${HOME}/start-vnc"
VNC_PASSWORD_FILE="${HOME}/.vncpass"
DEFAULT_GEOM="1280x720"

# ---------------- Helpers ----------------
info(){ printf "\e[1;36m[INFO]\e[0m %s\n" "$*"; }
warn(){ printf "\e[1;33m[WARN]\e[0m %s\n" "$*"; }
err(){ printf "\e[1;31m[ERR]\e[0m %s\n" "$*"; exit 1; }

detect_arch(){ uname -m || echo "unknown"; }

# ---------------- YouTube lock ----------------
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

# ---------------- Ensure prerequisites ----------------
info "Updating packages and installing required Termux packages..."
pkg update -y || warn "pkg update failed (continue)"
pkg install -y proot-distro wget curl coreutils util-linux openssh git vim x11-repo xorg-x11-server-utils x11vnc xvfb || true
command -v proot-distro >/dev/null 2>&1 || err "proot-distro not available."

# ---------------- Create distro profile if missing ----------------
if ! proot-distro list | grep -qi "^${PREFERRED}|^${FALLBACK}"; then
    info "No Kali/Debian profile found. Creating Kali profile..."
    mkdir -p "${PREFIX}/etc/proot-distro" || true
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
        info "Custom Kali profile created."
    else
        warn "No suitable tarball for arch '$arch'."
    fi
fi

# ---------------- Install distro ----------------
info "Installing distro..."
DIST="$PREFERRED"
set +e
proot-distro install "$DIST" || { warn "Failed to install $DIST"; DIST="$FALLBACK"; proot-distro install "$DIST" || err "Fallback failed"; }
set -e
info "Using distro: $DIST"

# ---------------- Bootstrap XFCE and VNC ----------------
if [ ! -f "$BOOTSTRAP_FLAG" ]; then
    info "Bootstrapping XFCE + VNC inside distro..."
    TMPF=$(mktemp)
    cat > "$TMPF" <<'EOF'
#!/usr/bin/env bash
set -e
export DEBIAN_FRONTEND=noninteractive
apt update -y || true
apt upgrade -y || true
apt install -y xfce4 xfce4-terminal xfce4-panel xfdesktop dbus-x11 x11-utils xterm nano python3 x11vnc xvfb || true

# Create user
if ! id -u termuxuser >/dev/null 2>&1; then
    useradd -m -s /bin/bash termuxuser || true
fi

# Create .xsession
USER_HOME=/home/termuxuser
mkdir -p ${USER_HOME}
cat > ${USER_HOME}/.xsession <<'XSE'
#!/bin/sh
export LANG=C
exec startxfce4
XSE
chmod +x ${USER_HOME}/.xsession || true
EOF

    proot-distro login "$DIST" -- bash -s < "$TMPF" || warn "Bootstrap warnings"
    rm -f "$TMPF"
    touch "$BOOTSTRAP_FLAG"
    info "Bootstrap completed."
else
    info "Bootstrap already done."
fi

# ---------------- Create VNC start wrapper ----------------
cat > "$START_WRAPPER" <<'EOS'
#!/usr/bin/env bash
set -euo pipefail

DISTRO="debian"   # change if using Kali
VNC_PASS_FILE="$HOME/.vncpass"
DISPLAY_NUM=":1"
GEOM="${GEOM:-1280x720}"

# Generate VNC password if missing
if [ ! -f "$VNC_PASS_FILE" ]; then
    PASS=$(tr -dc A-Za-z0-9 </dev/urandom | head -c 12)
    echo "$PASS" > "$VNC_PASS_FILE"
    echo "Generated VNC password: $PASS"
else
    PASS=$(cat "$VNC_PASS_FILE")
    echo "Using saved VNC password: $PASS"
fi

echo "Starting Xvfb and x11vnc inside $DISTRO..."
proot-distro login "$DISTRO" -- bash -lc "
    mkdir -p /home/termuxuser/.vnc
    echo '$PASS' | vncpasswd -f > /home/termuxuser/.vnc/passwd
    chmod 600 /home/termuxuser/.vnc/passwd
    export DISPLAY=$DISPLAY_NUM
    Xvfb $DISPLAY_NUM -screen 0 $GEOM -ac &
    sleep 2
    x11vnc -display $DISPLAY_NUM -rfbport 5901 -forever -passwdfile /home/termuxuser/.vnc/passwd &
    echo 'VNC server is running!'
"
echo "Connect your VNC client to 127.0.0.1:5901 with password: $PASS"
EOS

chmod +x "$START_WRAPPER"

# ---------------- Prompt to start VNC ----------------
read -r -p "Start VNC now? [y/N]: " ANSWER
ANSWER="${ANSWER:-N}"
if [[ "$ANSWER" =~ ^([yY][eE][sS]|[yY])$ ]]; then
    info "Starting VNC..."
    bash "$START_WRAPPER"
else
    info "You can start VNC later with: $START_WRAPPER"
fi

info "Done — HCO-KALI-Termux by Azhar"
