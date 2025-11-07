#!/usr/bin/env bash
# HCO-KALI-Termux.sh
# Installs Kali/Debian (proot-distro) + XFCE, creates start-xfce wrapper,
# and will auto-open Termux:X11 + start XFCE only after user confirms.
# Usage: chmod +x HCO-KALI-Termux.sh && ./HCO-KALI-Termux.sh
set -euo pipefail

# ---------- Config ----------
YOUTUBE_URL="https://youtube.com/@hackers_colony_tech?si=pvdCWZggTIuGb0ya"
PREFERRED="kali"
FALLBACK="debian"
BOOTSTRAP_FLAG="${HOME}/.hco_kali_bootstrap_done"
PREFIX="${PREFIX:-/data/data/com.termux/files/usr}"
TERMUX_X11_PKG="com.termux.x11"
DEFAULT_GEOM="1280x720"
START_WRAPPER="${HOME}/start-xfce"
DIST=""   # will be set to installed distro name

# ---------- helpers ----------
info(){ printf "\e[1;36m[INFO]\e[0m %s\n" "$*"; }
warn(){ printf "\e[1;33m[WARN]\e[0m %s\n" "$*"; }
err(){ printf "\e[1;31m[ERR]\e[0m %s\n" "$*"; exit 1; }

detect_arch(){ uname -m || echo "unknown"; }

launch_android_app(){
  pkgname="$1"
  if [ -z "$pkgname" ]; then return 1; fi
  if command -v monkey >/dev/null 2>&1; then
    monkey -p "$pkgname" 1 >/dev/null 2>&1 && return 0 || true
  fi
  if command -v am >/dev/null 2>&1; then
    am start -a android.intent.action.MAIN -n "${pkgname}/.MainActivity" >/dev/null 2>&1 && return 0 || true
    am start -a android.intent.action.MAIN -n "${pkgname}/.LauncherActivity" >/dev/null 2>&1 && return 0 || true
    am start -a android.intent.action.MAIN -p "${pkgname}" >/dev/null 2>&1 && return 0 || true
  fi
  if command -v termux-open-url >/dev/null 2>&1; then
    termux-open-url "https://github.com/termux/termux-x11/releases" >/dev/null 2>&1 || true
  fi
  return 2
}

# ---------- Unlock & YouTube redirect ----------
clear
echo -e "\e[1;33m🔒 TOOL LOCKED — HCO-KALI-Termux\e[0m"
echo "To continue please subscribe to Hackers Colony Tech on YouTube and click the bell."
echo -n "Redirecting to YouTube in "
for i in 9 8 7 6 5 4 3 2 1; do
  echo -n "$i "
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
pkg update -y || warn "pkg update failed (continuing)"
pkg install -y proot-distro wget curl coreutils util-linux openssh git || true
if ! command -v proot-distro >/dev/null 2>&1; then
  err "proot-distro not available. Install Termux (from F-Droid) and ensure proot-distro package is installed."
fi

# ---------- Create Kali profile if missing ----------
if ! proot-distro list | grep -qi "^${PREFERRED}\|^${FALLBACK}"; then
  info "No Kali/Debian profiles present. Attempting to create a Kali profile for your architecture..."
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
    warn "No suitable Kali tarball available for arch '$arch'. Will use Debian fallback."
  fi
fi

# ---------- Install distro (kali preferred, debian fallback) ----------
info "Attempting to install '${PREFERRED}' (if available), otherwise '${FALLBACK}'..."
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
  warn "Could not install '${PREFERRED}'. Trying fallback '${FALLBACK}'..."
  proot-distro install "${FALLBACK}" || err "Failed to install fallback distro '${FALLBACK}'. Check storage/network."
  DIST="${FALLBACK}"
else
  DIST="${PREFERRED}"
fi

info "Installed distro alias: ${DIST}"

# ---------- Bootstrap XFCE inside the distro ----------
if [ ! -f "${BOOTSTRAP_FLAG}" ]; then
  info "Bootstrapping XFCE and creating user 'termuxuser' inside ${DIST} (this may take a while)..."
  tmpf=$(mktemp)
  cat > "${tmpf}" <<'EOBOOT'
#!/usr/bin/env bash
set -e
export DEBIAN_FRONTEND=noninteractive
apt update -y || true
apt upgrade -y || true
# lightweight xfce components and essentials
apt install -y xfce4 xfce4-terminal xfce4-panel xfdesktop dbus-x11 x11-utils xterm sudo nano || true
# create user
if ! id -u termuxuser >/dev/null 2>&1; then
  useradd -m -s /bin/bash termuxuser || true
  echo "termuxuser:termux" | chpasswd || true
  usermod -aG sudo termuxuser || true
fi
# create .xsession to start xfce for the user
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
  info "Bootstrap already completed previously (flag present)."
fi

# ---------- Create start-xfce wrapper in HOME ----------
info "Creating start-xfce wrapper at ${START_WRAPPER} ..."
cat > "${START_WRAPPER}" <<'EOS'
#!/usr/bin/env bash
# start-xfce: starts XFCE inside installed proot-distro (Termux:X11 must be running)
set -euo pipefail
# detect distro name (kali preferred, fallback to debian)
if proot-distro list | grep -qi "^kali"; then
  DISTRO="kali"
elif proot-distro list | grep -qi "^hco-kali"; then
  DISTRO="hco-kali"
elif proot-distro list | grep -qi "^debian"; then
  DISTRO="debian"
else
  echo "[start-xfce] No supported distro found (kali/hco-kali/debian). Install first."; exit 1
fi
echo "[start-xfce] Using distro: ${DISTRO}"
# ensure Termux:X11 app likely running; we don't auto-install it here
export DISPLAY=:0
# start XFCE session as termuxuser (background)
proot-distro login "${DISTRO}" -- bash -lc "export DISPLAY=:0; sudo -u termuxuser /home/termuxuser/.xsession > /dev/null 2>&1 & disown" || { echo "[start-xfce] Failed to start XFCE inside distro."; exit 1; }
echo "[start-xfce] XFCE start command issued. Switch to Termux:X11 app to view the desktop."
EOS
chmod +x "${START_WRAPPER}" || true
info "start-xfce created and made executable."

# ---------- Prompt: open Termux:X11 now? ----------
echo
echo -e "\n\e[1;33mSetup finished.\e[0m"
echo "Would you like to open Termux:X11 now and start the XFCE desktop inside it?"
read -r -p "Open Termux:X11 now? [y/N]: " ANSWER
ANSWER="${ANSWER:-N}"

if [[ ! "$ANSWER" =~ ^([yY][eE][sS]|[yY])$ ]]; then
  info "Okay — not opening Termux:X11 now."
  cat <<MSG

To start later, first open the Termux:X11 app (Termux X server) manually, then run:
  ${START_WRAPPER}

Or run:
  proot-distro login ${DIST} -- bash -lc "export DISPLAY=:0; sudo -u termuxuser /home/termuxuser/.xsession &"

MSG
  exit 0
fi

# ---------- Attempt to launch Termux:X11 Android app ----------
info "User agreed. Attempting to launch Termux:X11 Android app (package: ${TERMUX_X11_PKG})..."
if pm list packages 2>/dev/null | grep -qi "${TERMUX_X11_PKG}"; then
  info "Termux:X11 app appears to be installed. Launching it..."
  launch_android_app "${TERMUX_X11_PKG}" || warn "Could not auto-launch Termux:X11 via intents; please open it manually."
else
  warn "Termux:X11 app not found on device. Opening download page..."
  if command -v termux-open-url >/dev/null 2>&1; then
    termux-open-url "https://github.com/termux/termux-x11/releases" >/dev/null 2>&1 || true
  elif command -v am >/dev/null 2>&1; then
    am start -a android.intent.action.VIEW -d "https://github.com/termux/termux-x11/releases" >/dev/null 2>&1 || true
  else
    echo "Please install Termux:X11 (package: ${TERMUX_X11_PKG}) from GitHub releases or mirror."
  fi
  warn "After installing Termux:X11, run ${START_WRAPPER}"
  exit 0
fi

# ---------- Wait and start XFCE via start-xfce ----------
info "Waiting a few seconds for the Termux:X11 app to initialize..."
sleep 4
info "Starting XFCE via ${START_WRAPPER} ..."
bash "${START_WRAPPER}" || warn "start-xfce returned warnings. Ensure Termux:X11 app is running and try again."

info "If everything worked, the XFCE desktop should appear inside the Termux:X11 app now."
info "If not, run the manual command printed above."

echo
echo "Done — HCO-KALI-Termux by Azhar"
