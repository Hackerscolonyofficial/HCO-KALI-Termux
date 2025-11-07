#!/usr/bin/env bash
# HCO-KALI-Termux.sh — VNC option added (TigerVNC)
# Author: Azhar | Hackers Colony
# Usage: chmod +x HCO-KALI-Termux.sh && ./HCO-KALI-Termux.sh

set -euo pipefail
DEBUG=1  # set to 0 to quiet debug output

# ---------- Config ----------
YOUTUBE_URL="https://youtube.com/@hackers_colony_tech?si=pvdCWZggTIuGb0ya"
PREFERRED="kali"
FALLBACK="debian"
BOOTSTRAP_FLAG="${HOME}/.hco_kali_bootstrap_done"
PREFIX="${PREFIX:-/data/data/com.termux/files/usr}"
START_WRAPPER="${HOME}/start-xfce"
DEFAULT_GEOM="1280x720"
DEFAULT_VNC_DISPLAY=":1"
DEFAULT_VNC_PORT=5901

info(){ printf "\e[1;36m[INFO]\e[0m %s\n" "$*"; }
warn(){ printf "\e[1;33m[WARN]\e[0m %s\n" "$*"; }
err(){ printf "\e[1;31m[ERR]\e[0m %s\n" "$*"; exit 1; }

# small helper to obtain local IP (best-effort)
get_local_ip(){
  # try ip route method
  if command -v ip >/dev/null 2>&1; then
    ip route get 8.8.8.8 2>/dev/null | awk '/src/ {for(i=1;i<=NF;i++){ if($i=="src"){print $(i+1); exit}}}'
    return
  fi
  # try hostname -I
  if command -v hostname >/dev/null 2>&1; then
    hostname -I 2>/dev/null | awk '{print $1}'
    return
  fi
  echo "127.0.0.1"
}

# ---------- Unlock & YouTube redirect ----------
clear
echo -e "\e[1;33m🔒 TOOL LOCKED — HCO-KALI-Termux\e[0m"
echo "To continue please subscribe to Hackers Colony Tech on YouTube and click the bell."
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

# ---------- Create Kali profile if missing (keeps previous behavior) ----------
if ! proot-distro list | grep -qi "^${PREFERRED}\|^${FALLBACK}"; then
  info "No Kali/Debian profiles present. Creating a profile..."
  mkdir -p "${PREFIX}/etc/proot-distro" || true
  arch=$(uname -m 2>/dev/null || echo "unknown")
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
    info "Custom Kali profile created: ${PREFIX}/etc/proot-distro/${PREFERRED}.sh"
  else
    warn "No suitable Kali tarball available for arch '$arch'. Will use Debian fallback."
  fi
fi

# ---------- Install distro (non-interactive) ----------
DIST="$PREFERRED"
if ! proot-distro list | grep -qi "^$DIST"; then
  info "Installing distro $DIST..."
  # force yes and continue in case proot-distro prompts
  echo "y" | proot-distro install "$DIST" >/dev/null 2>&1 || warn "Install finished with warnings."
else
  info "Distro $DIST already installed."
fi

if ! proot-distro list | grep -qi "^$DIST"; then
  DIST="$FALLBACK"
  info "Installing fallback $DIST..."
  echo "y" | proot-distro install "$DIST" >/dev/null 2>&1 || err "Fallback install failed."
fi
info "Using distro: $DIST"

# ---------- Bootstrap XFCE (unchanged) ----------
if [ ! -f "${BOOTSTRAP_FLAG}" ]; then
  info "Bootstrapping XFCE and creating user 'termuxuser' inside ${DIST} (this may take a while)..."
  tmpf=$(mktemp)
  cat > "${tmpf}" <<'EOBOOT'
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
  proot-distro login "${DIST}" -- bash -s < "${tmpf}" || warn "Bootstrap finished with warnings"
  rm -f "${tmpf}"
  touch "${BOOTSTRAP_FLAG}"
  info "Bootstrap completed."
else
  info "Bootstrap already completed previously (flag present)."
fi

# ---------- start-xfce wrapper ----------
info "Creating start-xfce wrapper at ${START_WRAPPER} ..."
cat > "${START_WRAPPER}" <<'EOS'
#!/usr/bin/env bash
set -euo pipefail
# detect distro alias
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
export DISPLAY=:0
proot-distro login "${DISTRO}" -- bash -lc "export DISPLAY=:0; sudo -u termuxuser /home/termuxuser/.xsession > /dev/null 2>&1 & disown"
EOS
chmod +x "${START_WRAPPER}" || true

# ---------- NEW: VNC flow ----------
echo
read -r -p "Use VNC (TigerVNC) instead of Termux:X11? [Y/n]: " use_vnc
use_vnc="${use_vnc:-Y}"
if [[ "$use_vnc" =~ ^([yY][eE][sS]|[yY])$ ]]; then
  info "Setting up VNC inside distro: ${DIST}"

  # ask for password or generate one
  DEFAULT_PASS=$(tr -dc 'A-Za-z0-9' </dev/urandom | head -c12)
  read -r -p "Enter VNC password (leave empty to use generated): " VNC_PASS
  if [ -z "$VNC_PASS" ]; then
    VNC_PASS="$DEFAULT_PASS"
    info "Using generated VNC password: $VNC_PASS"
  else
    info "Using provided VNC password."
  fi

  # Ask for display/port
  read -r -p "Enter VNC display number (default 1 -> port 5901): " VNC_DISPLAY_NUM
  VNC_DISPLAY_NUM="${VNC_DISPLAY_NUM:-1}"
  VNC_DISPLAY=":${VNC_DISPLAY_NUM}"
  VNC_PORT=$((5900 + VNC_DISPLAY_NUM))

  info "VNC will run on display ${VNC_DISPLAY} (port ${VNC_PORT})."

  # Install TigerVNC inside the distro and create password as termuxuser
  info "Installing TigerVNC inside ${DIST} (may take a minute)..."
  proot-distro login "${DIST}" -- bash -lc "export DEBIAN_FRONTEND=noninteractive; apt update -y || true; apt install -y tigervnc-standalone-server tigervnc-common || apt install -y tightvncserver || true"

  # create ~/.vnc and write password as termuxuser
  info "Configuring VNC password for user 'termuxuser' inside distro..."
  proot-distro login "${DIST}" -- bash -lc "mkdir -p /home/termuxuser/.vnc && chown -R termuxuser:termuxuser /home/termuxuser/.vnc"
  # create the vnc password file non-interactively (TigerVNC/tightvnc compatibility)
  proot-distro login "${DIST}" -- bash -lc "sudo -u termuxuser bash -lc 'printf \"%s\n%s\n\" \"${VNC_PASS}\" \"${VNC_PASS}\" | vncpasswd > /home/termuxuser/.vnc/passwd; chmod 600 /home/termuxuser/.vnc/passwd' " || warn "Could not run vncpasswd non-interactively (check inside distro)."

  # Stop any existing servers on that display, then start VNC
  info "Stopping any existing VNC session on ${VNC_DISPLAY} (if present)..."
  proot-distro login "${DIST}" -- bash -lc "sudo -u termuxuser bash -lc 'vncserver -kill ${VNC_DISPLAY} >/dev/null 2>&1 || true' || true"

  info "Starting VNC server on display ${VNC_DISPLAY} inside distro..."
  # we'll run without -localhost so remote clients can connect; change to -localhost to restrict to local only
  proot-distro login "${DIST}" -- bash -lc "sudo -u termuxuser bash -lc 'vncserver ${VNC_DISPLAY} -geometry ${DEFAULT_GEOM} -depth 24 >/home/termuxuser/.vnc/vncserver.log 2>&1 & disown' " || warn "vncserver start may have warnings."

  # get local IP (best effort) from Termux environment
  LOCAL_IP=$(get_local_ip)
  info "Local IP detected: ${LOCAL_IP}"

  VNC_URL="vnc://${LOCAL_IP}:${VNC_PORT}"
  info "Attempting to open VNC URL with system (vnc viewer) -> ${VNC_URL}"
  if command -v termux-open-url >/dev/null 2>&1; then
    termux-open-url "${VNC_URL}" >/dev/null 2>&1 || true
  elif command -v am >/dev/null 2>&1; then
    # try launching view intent for vnc scheme or fallback to GitHub / viewer
    am start -a android.intent.action.VIEW -d "${VNC_URL}" >/dev/null 2>&1 || true
  else
    warn "No termux-open-url or am available to auto-open a VNC viewer."
  fi

  echo
  info "VNC server should be running inside the distro."
  echo "Connect with the following details (or open the URL above in a VNC client):"
  echo "  IP:PORT -> ${LOCAL_IP}:${VNC_PORT}"
  echo "  Display -> ${VNC_DISPLAY}"
  echo "  Password -> ${VNC_PASS}"
  echo
  echo "If your Android VNC client can't connect to ${LOCAL_IP}, try 127.0.0.1:${VNC_PORT} (if you run a local tunnel)."
  echo "To stop the VNC server inside distro (run in Termux):"
  echo "  proot-distro login ${DIST} -- bash -lc \"sudo -u termuxuser vncserver -kill ${VNC_DISPLAY}\""
  echo

  # After starting VNC, optionally start the XFCE session inside the distro on display :1
  info "Starting XFCE session inside distro (will use the display created by VNC)..."
  proot-distro login "${DIST}" -- bash -lc "sudo -u termuxuser bash -lc 'export DISPLAY=${VNC_DISPLAY}; /home/termuxuser/.xsession >/dev/null 2>&1 & disown' " || warn "Could not start .xsession automatically; you can start inside distro: startxfce4"

  info "VNC setup complete."
  exit 0
else
  info "VNC not selected — continuing to Termux:X11 path (unchanged)."
  # (you can keep the Termux:X11 logic here from your script if you want)
fi

# If the script reaches here it means VNC was not selected and original path continues.
info "No VNC selected. Exiting (or continue with your original Termux:X11 flow)."
exit 0
