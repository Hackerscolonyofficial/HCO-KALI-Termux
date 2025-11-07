#!/usr/bin/env bash
# HCO-KALI-Termux.sh — full installer with secure bVNC auto-open via SSH tunnel
# Author: Azhar | Hackers Colony
# Usage: chmod +x HCO-KALI-Termux.sh && ./HCO-KALI-Termux.sh

set -euo pipefail

# ---------- Config ----------
YOUTUBE_URL="https://youtube.com/@hackers_colony_tech?si=pvdCWZggTIuGb0ya"
PREFERRED="kali"
FALLBACK="debian"
BOOTSTRAP_FLAG="${HOME}/.hco_kali_bootstrap_done"
PREFIX="${PREFIX:-/data/data/com.termux/files/usr}"
START_WRAPPER="${HOME}/start-bvnc"
DIST_USER="termuxuser"
VNC_PORT=5901
VNC_PASS_FILE="${HOME}/.hco_vnc_pass"
SSH_PORT=2222

# ---------- Helpers ----------
info(){ printf "\e[1;36m[INFO]\e[0m %s\n" "$*"; }
warn(){ printf "\e[1;33m[WARN]\e[0m %s\n" "$*"; }
err(){ printf "\e[1;31m[ERR]\e[0m %s\n" "$*"; exit 1; }
detect_arch(){ uname -m || echo "unknown"; }

# ---------- YouTube redirect ----------
clear
echo -e "\e[1;33m🔒 TOOL LOCKED — HCO-KALI-Termux\e[0m"
echo "Subscribe to Hackers Colony Tech on YouTube and click the bell."
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
info "Updating packages and installing essentials..."
pkg update -y || warn "pkg update failed"
pkg install -y proot-distro wget curl coreutils util-linux openssh git openssl || true
command -v proot-distro >/dev/null 2>&1 || err "proot-distro not installed. Install Termux from F-Droid and try again."

# ---------- Create Kali/Debian profile ----------
if ! proot-distro list | grep -qi "^${PREFERRED}|^${FALLBACK}"; then
  info "Creating Kali profile..."
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
    warn "No suitable Kali tarball for '$arch'. Fallback will be used."
  fi
fi

# ---------- Install distro ----------
DIST="$PREFERRED"
set +e
proot-distro install "$DIST" || { 
  warn "Failed to install $DIST. Trying fallback..."
  DIST="$FALLBACK"
  proot-distro install "$DIST" || err "Fallback $FALLBACK install failed."
}
set -e
info "Using distro: $DIST"

# ---------- Bootstrap bVNC inside distro ----------
if [ ! -f "$BOOTSTRAP_FLAG" ]; then
  info "Bootstrapping bVNC and user '$DIST_USER'..."
  TMP_SCRIPT=$(mktemp)
  cat > "$TMP_SCRIPT" <<'EOF'
#!/usr/bin/env bash
set -e
export DEBIAN_FRONTEND=noninteractive
apt update -y || true
apt upgrade -y || true
apt install -y x11-xkb-utils dbus-x11 nano openbox xterm wget curl python3 lxde-core lxterminal sudo net-tools openssh-server x11vnc || true
if ! id -u termuxuser >/dev/null 2>&1; then
  useradd -m -s /bin/bash termuxuser || true
  echo "termuxuser:termux" | chpasswd || true
  usermod -aG sudo termuxuser || true
fi
mkdir -p /var/run/sshd
sed -i 's/^#PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config
sed -i 's/^#PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config
service ssh restart || /usr/sbin/sshd
EOF
  proot-distro login "$DIST" -- bash -s < "$TMP_SCRIPT" || warn "Bootstrap finished with warnings"
  rm -f "$TMP_SCRIPT"
  touch "$BOOTSTRAP_FLAG"
  info "Bootstrap completed."
else
  info "Bootstrap already done."
fi

# ---------- Generate VNC password ----------
if [ -f "$VNC_PASS_FILE" ]; then
  VNC_PASS=$(cat "$VNC_PASS_FILE")
else
  VNC_PASS=$(openssl rand -base64 12)
  echo "$VNC_PASS" > "$VNC_PASS_FILE"
  chmod 600 "$VNC_PASS_FILE"
  info "Generated VNC password saved to $VNC_PASS_FILE"
fi

# ---------- Create start-bvnc wrapper ----------
cat > "$START_WRAPPER" <<EOF
#!/usr/bin/env bash
DIST="$DIST"
USER="$DIST_USER"
VNC_PORT=$VNC_PORT
VNC_PASS="$VNC_PASS"
SSH_PORT=$SSH_PORT

echo "[INFO] Starting bVNC server inside \$DIST (localhost only)..."

# Start bVNC inside distro bound to 127.0.0.1
proot-distro login "\$DIST" -- bash -lc "
sudo -u \$USER mkdir -p ~/.vnc
echo \$VNC_PASS | x11vnc -storepasswd -f > ~/.vnc/passwd
x11vnc -display :0 -rfbport \$VNC_PORT -rfbauth ~/.vnc/passwd -forever -shared -bg -listen 127.0.0.1
"

# Start SSH tunnel from distro localhost to Termux host
ssh -o StrictHostKeyChecking=no -f -N -L \$VNC_PORT:127.0.0.1:\$VNC_PORT \$USER@127.0.0.1 -p \$SSH_PORT || echo "SSH tunnel failed. Make sure SSH server in distro is running."

# Detect Termux host IP
HOST_IP=\$(ip addr show wlan0 2>/dev/null | grep 'inet ' | awk '{print \$2}' | cut -d/ -f1)
HOST_IP=\${HOST_IP:-127.0.0.1}

echo "[INFO] Opening bVNC to vnc://\$HOST_IP:\$VNC_PORT"
if command -v am >/dev/null 2>&1; then
  am start -a android.intent.action.VIEW -d vnc://\$HOST_IP:\$VNC_PORT >/dev/null 2>&1 || echo "Open bVNC manually to \$HOST_IP:\$VNC_PORT"
elif command -v termux-open-url >/dev/null 2>&1; then
  termux-open-url vnc://\$HOST_IP:\$VNC_PORT >/dev/null 2>&1 || echo "Open bVNC manually to \$HOST_IP:\$VNC_PORT"
fi
EOF
chmod +x "$START_WRAPPER"

# ---------- Prompt to start bVNC ----------
read -r -p $'\nDo you want to start bVNC now? [Y/n]: ' start_bvnc
start_bvnc="${start_bvnc:-Y}"
if [[ "$start_bvnc" =~ ^([yY][eE][sS]|[yY])$ ]]; then
  bash "$START_WRAPPER"
else
  info "You can start bVNC later with: $START_WRAPPER"
fi

info "Setup finished — HCO-KALI-Termux by Azhar"
