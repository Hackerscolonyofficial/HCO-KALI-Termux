#!/usr/bin/env bash
# HCO-KALI-Termux.sh (updated with interactive Termux:X11 detection)
# Author: Azhar | Hackers Colony
# Usage: chmod +x HCO-KALI-Termux.sh && ./HCO-KALI-Termux.sh [--debug]

set -euo pipefail

DEBUG=0
if [[ "${1:-}" == "--debug" ]]; then
  DEBUG=1
  echo -e "\e[1;35m[DEBUG MODE ENABLED]\e[0m"
fi

# ---------- Config ----------
YOUTUBE_URL="https://youtube.com/@hackers_colony_tech?si=pvdCWZggTIuGb0ya"
PREFERRED="kali"
FALLBACK="debian"
BOOTSTRAP_FLAG="${HOME}/.hco_kali_bootstrap_done"
PREFIX="${PREFIX:-/data/data/com.termux/files/usr}"
TERMUX_X11_CANDIDATES=( \
  "com.termux.x11" \
  "io.github.termux.x11" \
  "com.termux.x11.debug" \
  "com.termux.x11.legacy" \
)
START_WRAPPER="${HOME}/start-xfce"
DEFAULT_GEOM="1280x720"

# ---------- Helpers ----------
info(){ printf "\e[1;36m[INFO]\e[0m %s\n" "$*"; }
warn(){ printf "\e[1;33m[WARN]\e[0m %s\n" "$*"; }
err(){ printf "\e[1;31m[ERR]\e[0m %s\n" "$*"; exit 1; }

detect_arch(){ uname -m 2>/dev/null || echo "unknown"; }

# Try to launch an Android package in multiple ways; returns 0 on success
launch_android_pkg(){
  pkgname="$1"
  if [ -z "$pkgname" ]; then
    return 1
  fi

  [[ "$DEBUG" -eq 1 ]] && echo "[DEBUG] Trying to launch Android package: $pkgname"

  if command -v am >/dev/null 2>&1; then
    # list of likely activities / attempts
    activities=(
      ".MainActivity" ".LauncherActivity" ".TermuxActivity" ".StartActivity" ".Main" "" )
    for a in "${activities[@]}"; do
      if [ -n "$a" ]; then
        # try explicit component
        if am start -a android.intent.action.MAIN -n "${pkgname}${a}" >/dev/null 2>&1; then
          [[ "$DEBUG" -eq 1 ]] && echo "[DEBUG] Launched activity: ${pkgname}${a}"
          return 0
        fi
        # try VIEW intent to package component
        if am start -a android.intent.action.VIEW -n "${pkgname}${a}" >/dev/null 2>&1; then
          [[ "$DEBUG" -eq 1 ]] && echo "[DEBUG] Launched VIEW activity: ${pkgname}${a}"
          return 0
        fi
      else
        # generic package-level MAIN intent
        if am start -a android.intent.action.MAIN -p "${pkgname}" >/dev/null 2>&1; then
          [[ "$DEBUG" -eq 1 ]] && echo "[DEBUG] Launched package MAIN intent: $pkgname"
          return 0
        fi
      fi
    done

    # Try opening market/play view
    if am start -a android.intent.action.VIEW -d "market://details?id=${pkgname}" >/dev/null 2>&1; then
      [[ "$DEBUG" -eq 1 ]] && echo "[DEBUG] Opened market page for $pkgname"
      return 0
    fi
    # try general view with https fallback
    if am start -a android.intent.action.VIEW -d "https://play.google.com/store/apps/details?id=${pkgname}" >/dev/null 2>&1; then
      [[ "$DEBUG" -eq 1 ]] && echo "[DEBUG] Opened Play URL for $pkgname"
      return 0
    fi
  fi

  # monkey fallback
  if command -v monkey >/dev/null 2>&1; then
    if monkey -p "$pkgname" 1 >/dev/null 2>&1; then
      [[ "$DEBUG" -eq 1 ]] && echo "[DEBUG] Launched package via monkey: $pkgname"
      return 0
    fi
  fi

  # termux-open-url fallback to Play/GitHub releases
  if command -v termux-open-url >/dev/null 2>&1; then
    termux-open-url "https://play.google.com/store/apps/details?id=${pkgname}" >/dev/null 2>&1 || true
  fi

  return 2
}

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

read -r -p $'\nPress ENTER when back in Termux to continue: '

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
rc=0
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
  if proot-distro list | grep -qi "^${FALLBACK}"; then
    info "Fallback '${FALLBACK}' is already installed. Using existing '${FALLBACK}'."
  else
    proot-distro install "${FALLBACK}" || err "Failed to install fallback distro '${FALLBACK}'. Check storage/network."
  fi
  DIST="${FALLBACK}"
else
  DIST="${PREFERRED}"
fi

info "Using distro alias: ${DIST}"

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

To start later (after you open Termux:X11 app manually), run:
${START_WRAPPER}

Or:
proot-distro login ${DIST} -- bash -lc "export DISPLAY=:0; sudo -u termuxuser /home/termuxuser/.xsession &"

MSG
  exit 0
fi

# ---------- Interactive detection & launch ----------
info "User agreed. Detecting Termux:X11 package..."

# If pm isn't available, we can't list packages — warn and fallback to open GitHub releases
if ! command -v pm >/dev/null 2>&1; then
  warn "pm command not available in PATH. Can't enumerate installed packages."
  if command -v termux-open-url >/dev/null 2>&1; then
    termux-open-url "https://github.com/termux/termux-x11/releases" >/dev/null 2>&1 || true
  elif command -v am >/dev/null 2>&1; then
    am start -a android.intent.action.VIEW -d "https://github.com/termux/termux-x11/releases" >/dev/null 2>&1 || true
  fi
  warn "Install Termux:X11 and then run: ${START_WRAPPER}"
  exit 0
fi

# Gather candidate packages mentioning termux/x11
mapfile -t candidates < <(pm list packages 2>/dev/null | tr '[:upper:]' '[:lower:]' | grep -iE 'x11|termux' | sed 's/package://g' || true)

if [ "${#candidates[@]}" -eq 0 ]; then
  warn "No installed packages containing 'termux' or 'x11' found."
  if command -v termux-open-url >/dev/null 2>&1; then
    termux-open-url "https://github.com/termux/termux-x11/releases" >/dev/null 2>&1 || true
  elif command -v am >/dev/null 2>&1; then
    am start -a android.intent.action.VIEW -d "https://github.com/termux/termux-x11/releases" >/dev/null 2>&1 || true
  fi
  warn "Please install Termux:X11 and re-run this script."
  exit 1
fi

if [ "$DEBUG" -eq 1 ]; then
  info "Debug: Found the following packages mentioning 'x11' or 'termux':"
  for p in "${candidates[@]}"; do
    echo " - $p"
  done
fi

# Try to auto-detect the most likely Termux:X11 package (first package containing 'x11')
TERMUX_X11_PKG=""
for p in "${candidates[@]}"; do
  if [[ "$p" =~ x11 ]]; then
    TERMUX_X11_PKG="$p"
    [[ "$DEBUG" -eq 1 ]] && echo "[DEBUG] Auto-detected x11 candidate: $TERMUX_X11_PKG"
    break
  fi
done

# If still empty (no 'x11'), offer the user a selection from candidates
if [ -z "$TERMUX_X11_PKG" ]; then
  echo -e "\nMultiple candidate packages found. Please pick the Termux:X11 package to launch (enter number):"
  PS3="Select package number: "
  select pkg_choice in "${candidates[@]}"; do
    if [ -n "$pkg_choice" ]; then
      TERMUX_X11_PKG="$pkg_choice"
      break
    else
      echo "Invalid selection. Try again."
    fi
  done
fi

info "Using Termux:X11 package: ${TERMUX_X11_PKG}"
if launch_android_pkg "${TERMUX_X11_PKG}"; then
  info "Launched Termux:X11 (or handed control to system)."
else
  warn "Could not auto-launch Termux:X11 via intents/monkey; please open it manually."
  warn "After installing or opening Termux:X11, run: ${START_WRAPPER}"
  # show a short sample of candidates for debugging
  if [ "$DEBUG" -eq 1 ]; then
    echo "[DEBUG] Candidate list (first 12):"
    for ((i=0;i<${#candidates[@]} && i<12;i++)); do echo " - ${candidates[$i]}"; done
  fi
  exit 0
fi

# ---------- Wait a few seconds and start XFCE via start-xfce ----------
info "Waiting a few seconds for the Termux:X11 app to initialize..."
sleep 4
info "Starting XFCE via ${START_WRAPPER} ..."
bash "${START_WRAPPER}" || warn "start-xfce returned warnings. Ensure Termux:X11 app is running and try again."

info "If everything worked, the XFCE desktop should appear inside the Termux:X11 app now."
info "If not, run the manual command printed above."

echo
echo "Done — HCO-KALI-Termux by Azhar"
