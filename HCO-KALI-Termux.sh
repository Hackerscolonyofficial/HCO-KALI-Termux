#!/usr/bin/env bash
# HCO-KALI-Termux.sh (robust Termux:X11 detection)
# Author: Azhar | Hackers Colony
# Usage: chmod +x HCO-KALI-Termux.sh && ./HCO-KALI-Termux.sh

set -euo pipefail

DEBUG=1  # set to 1 for extra debug output

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

# ---------- Detect Termux:X11 package ----------
detect_termux_x11_pkg(){
  # First try pm if available
  if command -v pm >/dev/null 2>&1; then
    local candidate
    for pkg in "${TERMUX_X11_CANDIDATES[@]}"; do
      if pm list packages 2>/dev/null | grep -qi "package:${pkg}"; then
        echo "$pkg"
        return 0
      fi
    done
    # Looser matching: any package containing 'termux' and 'x11'
    candidate=$(pm list packages 2>/dev/null | tr '[:upper:]' '[:lower:]' | grep -Eo 'package:[a-z0-9.-]*termux[a-z0-9.-]*x11[a-z0-9._-]*' | head -n1 | sed 's/package://')
    if [ -n "$candidate" ]; then
      echo "$candidate"
      return 0
    fi
  fi

  # Next, try common known package names (F-Droid/Play)
  for pkg in "${TERMUX_X11_CANDIDATES[@]}"; do
    echo "$pkg"  # just assume it is installed
    return 0
  done

  # If still nothing, ask user
  read -r -p "Enter the Termux:X11 package name installed on your device: " pkgname
  echo "$pkgname"
  return 0
}

# ---------- Launch Android package ----------
launch_android_pkg(){
  local pkgname="$1"
  [[ -z "$pkgname" ]] && return 1

  local activities=(".MainActivity" ".LauncherActivity" ".TermuxActivity" ".StartActivity" "")
  for a in "${activities[@]}"; do
    if [ -n "$a" ] && am start -a android.intent.action.MAIN -n "${pkgname}${a}" >/dev/null 2>&1; then
      [[ $DEBUG -eq 1 ]] && echo "[DEBUG] Launched activity: ${pkgname}${a}"
      return 0
    fi
  done

  if am start -a android.intent.action.MAIN -p "$pkgname" >/dev/null 2>&1; then
    [[ $DEBUG -eq 1 ]] && echo "[DEBUG] Launched package: $pkgname"
    return 0
  fi

  if command -v monkey >/dev/null 2>&1; then
    monkey -p "$pkgname" 1 >/dev/null 2>&1 && return 0
  fi

  if command -v termux-open-url >/dev/null 2>&1; then
    termux-open-url "https://play.google.com/store/apps/details?id=${pkgname}" >/dev/null 2>&1 || true
  fi
  return 2
}

# ---------- YouTube redirect ----------
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
set +e
proot-distro install "${PREFERRED}" >/dev/null 2>&1
if [ $? -ne 0 ]; then
  warn "Could not install ${PREFERRED}, using fallback ${FALLBACK}"
  DIST="$FALLBACK"
  proot-distro install "${FALLBACK}" || err "Fallback failed."
fi
set -e
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

# ---------- Launch Termux:X11 ----------
info "Detecting Termux:X11 package..."
TERMUX_X11_PKG=$(detect_termux_x11_pkg)
info "Launching Termux:X11 ($TERMUX_X11_PKG)..."
launch_android_pkg "$TERMUX_X11_PKG" || warn "Could not auto-launch; open it manually."

sleep 4
info "Starting XFCE desktop..."
bash "$START_WRAPPER"
info "Done — HCO-KALI-Termux by Azhar"
