#!/usr/bin/env bash
# HCO-KALI-Termux.sh — fully fixed & retry-enabled
# Author: Azhar | Hackers Colony
# Usage: chmod +x HCO-KALI-Termux.sh && ./HCO-KALI-Termux.sh

set -euo pipefail
DEBUG=1  # set to 1 for debug output

# ---------- Config ----------
YOUTUBE_URL="https://youtube.com/@hackers_colony_tech?si=pvdCWZggTIuGb0ya"
PREFERRED="kali"
FALLBACK="debian"
BOOTSTRAP_FLAG="${HOME}/.hco_kali_bootstrap_done"
PREFIX="${PREFIX:-/data/data/com.termux/files/usr}"
START_WRAPPER="${HOME}/start-xfce"
DEFAULT_GEOM="1280x720"

TERMUX_X11_CANDIDATES=( \
  "io.github.termux.x11" \
  "com.termux.x11" \
  "com.termux.x11.debug" \
)

info(){ printf "\e[1;36m[INFO]\e[0m %s\n" "$*"; }
warn(){ printf "\e[1;33m[WARN]\e[0m %s\n" "$*"; }
err(){ printf "\e[1;31m[ERR]\e[0m %s\n" "$*"; exit 1; }

# ---------- Unlock & YouTube redirect ----------
clear
echo -e "\e[1;33m🔒 TOOL LOCKED — HCO-KALI-Termux\e[0m"
echo "Subscribe to Hackers Colony Tech on YouTube and click the bell."
echo -n "Redirecting in "
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
  echo "Open manually: $YOUTUBE_URL"
fi

read -r -p $'\nPress ENTER when back in Termux to continue: '

# ---------- Ensure prerequisites ----------
info "Updating packages and installing proot-distro..."
pkg update -y || warn "pkg update failed"
pkg install -y proot-distro wget curl coreutils util-linux openssh git || true
command -v proot-distro >/dev/null 2>&1 || err "proot-distro not available."

# ---------- Create Kali profile if missing ----------
if ! proot-distro list | grep -qi "^${PREFERRED}\|^${FALLBACK}"; then
  info "Creating Kali profile..."
  mkdir -p "${PREFIX}/etc/proot-distro" || true
  arch=$(uname -m)
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
  fi
fi

# ---------- Install distro ----------
DIST="$PREFERRED"
if ! proot-distro list | grep -qi "^$DIST"; then
  info "Installing distro $DIST..."
  echo "y" | proot-distro install "$DIST" >/dev/null 2>&1 || warn "Install finished with warnings."
else
  info "Distro $DIST already installed."
fi

# fallback if preferred fails
if ! proot-distro list | grep -qi "^$DIST"; then
  DIST="$FALLBACK"
  info "Installing fallback $DIST..."
  echo "y" | proot-distro install "$DIST" >/dev/null 2>&1 || err "Fallback install failed."
fi
info "Using distro: $DIST"

# ---------- Bootstrap XFCE ----------
if [ ! -f "$BOOTSTRAP_FLAG" ]; then
  info "Bootstrapping XFCE..."
  tmpf=$(mktemp)
  cat > "$tmpf" <<'EOBOOT'
#!/usr/bin/env bash
set -e
export DEBIAN_FRONTEND=noninteractive
apt update -y || true
apt upgrade -y || true
apt install -y xfce4 xfce4-terminal xfce4-panel xfdesktop dbus-x11 x11-utils xterm sudo nano || true
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
  proot-distro login "$DIST" -- bash -s < "$tmpf" || warn "Bootstrap finished with warnings"
  rm -f "$tmpf"
  touch "$BOOTSTRAP_FLAG"
  info "Bootstrap completed."
else
  info "Bootstrap already done."
fi

# ---------- start-xfce wrapper ----------
cat > "$START_WRAPPER" <<'EOS'
#!/usr/bin/env bash
set -euo pipefail
DISTRO=$(proot-distro list | grep -E 'kali|debian|hco-kali' | head -n1)
export DISPLAY=:0
proot-distro login "$DISTRO" -- bash -lc "export DISPLAY=:0; sudo -u termuxuser /home/termuxuser/.xsession > /dev/null 2>&1 & disown"
EOS
chmod +x "$START_WRAPPER"

# ---------- Robust Termux:X11 detection & launch with retry ----------
while true; do
  info "Detecting Termux:X11 package..."
  TERMUX_X11_PKG=$(pm list packages 2>/dev/null | tr '[:upper:]' '[:lower:]' | grep -E 'termux.*x11' | head -n1 | sed 's/package://')
  if [ -z "$TERMUX_X11_PKG" ]; then
    for pkg in "${TERMUX_X11_CANDIDATES[@]}"; do
      if pm list packages 2>/dev/null | grep -qi "$pkg"; then
        TERMUX_X11_PKG="$pkg"
        break
      fi
    done
  fi

  if [ -n "$TERMUX_X11_PKG" ]; then
    info "Termux:X11 package found: $TERMUX_X11_PKG"
    break
  fi

  warn "Termux:X11 not found on device."
  read -r -p "Did you install Termux:X11? Press ENTER to retry or Ctrl+C to exit..." _
done

# Try launching Termux:X11
launched=0
for activity in ".MainActivity" ".LauncherActivity" ".TermuxActivity" ".StartActivity" ""; do
  if [ -n "$activity" ] && am start -a android.intent.action.MAIN -n "${TERMUX_X11_PKG}${activity}" >/dev/null 2>&1; then
    info "Launched Termux:X11 activity: ${TERMUX_X11_PKG}${activity}"
    launched=1
    break
  fi
done

if [ $launched -eq 0 ] && am start -a android.intent.action.MAIN -p "$TERMUX_X11_PKG" >/dev/null 2>&1; then
  info "Launched Termux:X11 package: $TERMUX_X11_PKG"
  launched=1
fi

if [ $launched -eq 0 ] && command -v monkey >/dev/null 2>&1; then
  monkey -p "$TERMUX_X11_PKG" 1 >/dev/null 2>&1 && launched=1 && info "Launched Termux:X11 via monkey"
fi

if [ $launched -eq 0 ]; then
  warn "Could not auto-launch Termux:X11. Opening GitHub releases page..."
  termux-open-url "https://github.com/termux/termux-x11/releases" >/dev/null 2>&1 || true
fi

sleep 4
info "Starting XFCE desktop..."
bash "$START_WRAPPER"

info "Done — HCO-KALI-Termux by Azhar"
