#!/usr/bin/env bash
# HCO-KALI-Termux.sh — Full installer with auto VNC start & auto-port
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
DISPLAY_NUM=":1"

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

# ---------------- Prerequisites ----------------
info "Updating packages..."
pkg update -y || warn "pkg update failed"
pkg install -y proot-distro wget curl coreutils util-linux git vim x11-repo x11-utils x11vnc xvfb || true
command -v proot-distro >/dev/null 2>&1 || err "proot-distro missing"

# ---------------- Distro install ----------------
if ! proot-distro list | grep -qi "^${PREFERRED}|^${FALLBACK}"; then
    info "Creating Kali profile..."
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
        mkdir -p "${PREFIX}/etc/proot-distro"
        cat > "${PREFIX}/etc/proot-distro/${PREFERRED}.sh" <<EOF
DISTRO_NAME="Kali Linux (HCO profile)"
DISTRO_COMMENT="Kali Linux custom profile (HCO)"
TARBALL_URL="${TARBALL_URL}"
TARBALL_SHA256=""
EOF
        info "Custom Kali profile created."
    else
        warn "No suitable tarball for arch $arch"
    fi
fi

# Install distro
DIST="$PREFERRED"
set +e
proot-distro install "$DIST" || { warn "$DIST failed, trying fallback"; DIST="$FALLBACK"; proot-distro install "$DIST" || err "Fallback failed"; }
set -e
info "Using distro: $DIST"

# ---------------- Bootstrap XFCE ----------------
if [ ! -f "$BOOTSTRAP_FLAG" ]; then
    info "Bootstrapping XFCE inside $DIST..."
    TMPF=$(mktemp)
    cat > "$TMPF" <<'EOF'
#!/usr/bin/env bash
set -e
export DEBIAN_FRONTEND=noninteractive
apt update -y || true
apt upgrade -y || true
apt install -y xfce4 xfce4-terminal xfce4-panel xfdesktop dbus-x11 x11-utils x11vnc xvfb nano || true

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

# ---------------- Create VNC wrapper with auto-port ----------------
cat > "$START_WRAPPER" <<'EOS'
#!/usr/bin/env bash
set -euo pipefail

DISTRO="'"$DIST"'"
DISPLAY_NUM=":1"
DEFAULT_GEOM="1280x720"
VNC_PASS_FILE="$HOME/.vncpass"

# Generate VNC password if missing
if [ ! -f "$VNC_PASS_FILE" ]; then
    PASS=$(tr -dc A-Za-z0-9 </dev/urandom | head -c 12)
    echo "$PASS" > "$VNC_PASS_FILE"
else
    PASS=$(cat "$VNC_PASS_FILE")
fi

echo "[INFO] Using VNC password: $PASS"

# Auto detect free port
PORT=5901
while netstat -tuln | grep -q ":$PORT"; do
    PORT=$((PORT+1))
done
echo "[INFO] VNC server will use port $PORT"

# Start VNC inside distro
proot-distro login "$DISTRO" -- bash -lc "
mkdir -p /home/termuxuser/.vnc
echo '$PASS' | vncpasswd -f > /home/termuxuser/.vnc/passwd
chmod 600 /home/termuxuser/.vnc/passwd
export DISPLAY=$DISPLAY_NUM
Xvfb $DISPLAY_NUM -screen 0 $DEFAULT_GEOM -ac &
sleep 2
x11vnc -display $DISPLAY_NUM -rfbport $PORT -forever -passwdfile /home/termuxuser/.vnc/passwd &
echo '[INFO] VNC server running on 127.0.0.1:'\$PORT
"
EOS

chmod +x "$START_WRAPPER"

# ---------------- Auto-start VNC ----------------
info "Auto-starting VNC..."
bash "$START_WRAPPER"

info "Done — HCO-KALI-Termux by Azhar"
info "Connect your VNC client to 127.0.0.1:<port> using password from $VNC_PASSWORD_FILE"
