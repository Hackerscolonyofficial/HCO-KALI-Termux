#!/usr/bin/env bash
# HCO-KALI-Termux.sh — bVNC with AES-encrypted saved VNC password
# Author: Azhar | Hackers Colony
# Usage: chmod +x HCO-KALI-Termux.sh && ./HCO-KALI-Termux.sh

set -euo pipefail
DEBUG=1   # set to 0 to quiet debug output

# ---------- Config ----------
YOUTUBE_URL="https://youtube.com/@hackers_colony_tech?si=pvdCWZggTIuGb0ya"
PREFERRED="kali"
FALLBACK="debian"
BOOTSTRAP_FLAG="${HOME}/.hco_kali_bootstrap_done"
PREFIX="${PREFIX:-/data/data/com.termux/files/usr}"
START_WRAPPER="${HOME}/start-xfce"
DEFAULT_GEOM="1280x720"
DEFAULT_VNC_DISPLAY_NUM=1   # display :1 -> port 5901

VNC_PASS_FILE="${HOME}/.hco_vnc_pass.enc"   # AES-encrypted file
OPENSSL_REQUIRED=1

TERMUX_X11_CANDIDATES=( "io.github.termux.x11" "com.termux.x11" "com.termux.x11.debug" )

info(){ printf "\e[1;36m[INFO]\e[0m %s\n" "$*"; }
warn(){ printf "\e[1;33m[WARN]\e[0m %s\n" "$*"; }
err(){ printf "\e[1;31m[ERR]\e[0m %s\n" "$*"; exit 1; }

# ---------- small helpers ----------
get_local_ip(){
  if command -v ip >/dev/null 2>&1; then
    ip route get 8.8.8.8 2>/dev/null | awk '/src/ {for(i=1;i<=NF;i++){ if($i=="src"){print $(i+1); exit}}}'
    return
  fi
  if command -v hostname >/dev/null 2>&1; then
    hostname -I 2>/dev/null | awk '{print $1; exit}'
    return
  fi
  if command -v ifconfig >/dev/null 2>&1; then
    ifconfig 2>/dev/null | awk '/inet / && $2 != "127.0.0.1" {print $2; exit}'
    return
  fi
  echo "127.0.0.1"
}

randpass(){
  tr -dc 'A-Za-z0-9' </dev/urandom | head -c12 || echo "hcoVncPass123"
}

# ---------- check/install openssl ----------
ensure_openssl(){
  if command -v openssl >/dev/null 2>&1; then
    return 0
  fi
  warn "openssl not found — attempting to install openssl in Termux (may ask for confirmation)..."
  if command -v pkg >/dev/null 2>&1; then
    pkg install -y openssl || { warn "Could not install openssl automatically."; return 1; }
    return 0
  fi
  warn "No package manager available to install openssl. AES encryption will not be available."
  return 1
}

encrypt_password(){
  local plain="$1"
  local master="$2"
  if command -v openssl >/dev/null 2>&1; then
    printf "%s" "$plain" | openssl enc -aes-256-cbc -pbkdf2 -iter 100000 -salt -pass pass:"$master" -out "$VNC_PASS_FILE"
    chmod 600 "$VNC_PASS_FILE"
    return $?
  else
    # fallback to base64 (insecure)
    printf "%s" "$plain" | base64 > "${VNC_PASS_FILE}.b64"
    chmod 600 "${VNC_PASS_FILE}.b64"
    warn "openssl not available — saved password in base64 at ${VNC_PASS_FILE}.b64 (insecure)."
    return 0
  fi
}

decrypt_password(){
  local master="$1"
  if command -v openssl >/dev/null 2>&1 && [ -f "$VNC_PASS_FILE" ]; then
    if ! plaintext=$(openssl enc -d -aes-256-cbc -pbkdf2 -iter 100000 -in "$VNC_PASS_FILE" -pass pass:"$master" 2>/dev/null); then
      return 1
    fi
    printf "%s" "$plaintext"
    return 0
  elif [ -f "${VNC_PASS_FILE}.b64" ]; then
    base64 --decode "${VNC_PASS_FILE}.b64" 2>/dev/null || return 1
    return 0
  fi
  return 1
}

# ---------- Unlock & YouTube redirect ----------
clear
echo -e "\e[1;33m🔒 TOOL LOCKED — HCO-KALI-Termux\e[0m"
echo "To continue please subscribe to Hackers Colony Tech on YouTube and click the bell."
echo -n "Redirecting to YouTube in "
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
command -v proot-distro >/dev/null 2>&1 || err "proot-distro not available. Install Termux (from F-Droid) and ensure proot-distro package is installed."

# ensure openssl (best-effort)
if ! ensure_openssl; then
  warn "Continuing without AES encryption support."
fi

# ---------- Create Kali profile if missing ----------
if ! proot-distro list | grep -qi "^${PREFERRED}\|^${FALLBACK}"; then
  info "No Kali/Debian profiles present. Creating a Kali profile for your architecture..."
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
  fi
fi

# ---------- Install distro (non-interactive) ----------
DIST="$PREFERRED"
if ! proot-distro list | grep -qi "^$DIST"; then
  info "Installing distro $DIST (non-interactive)..."
  echo "y" | proot-distro install "$DIST" >/dev/null 2>&1 || warn "Install finished with warnings."
else
  info "Distro $DIST already installed."
fi

# fallback to Debian if needed
if ! proot-distro list | grep -qi "^$DIST"; then
  DIST="$FALLBACK"
  info "Installing fallback distro $DIST..."
  echo "y" | proot-distro install "$DIST" >/dev/null 2>&1 || err "Fallback install failed."
fi
info "Using distro: $DIST"

# ---------- Bootstrap XFCE inside distro ----------
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
# create termuxuser
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
  rm -f "$tmpf"
  touch "$BOOTSTRAP_FLAG"
  info "Bootstrap completed."
else
  info "Bootstrap already completed previously (flag present)."
fi

# ---------- Create start-xfce wrapper ----------
info "Creating start-xfce wrapper at ${START_WRAPPER} ..."
cat > "${START_WRAPPER}" <<'EOS'
#!/usr/bin/env bash
set -euo pipefail
# choose first matching alias
DISTRO=$(proot-distro list | grep -E 'kali|debian|hco-kali' | head -n1)
export DISPLAY=:0
proot-distro login "$DISTRO" -- bash -lc "export DISPLAY=:0; sudo -u termuxuser /home/termuxuser/.xsession > /dev/null 2>&1 & disown"
EOS
chmod +x "${START_WRAPPER}" || true

# ---------- bVNC (TigerVNC) flow with AES-encrypted password storage ----------
echo
read -r -p "Use bVNC (TigerVNC) instead of Termux:X11? [Y/n]: " use_vnc
use_vnc="${use_vnc:-Y}"
if [[ "$use_vnc" =~ ^([yY][eE][sS]|[yY])$ ]]; then
  info "Setting up bVNC/TigerVNC inside distro: ${DIST}"

  # If encrypted password exists, offer reuse
  VNC_PASS=""
  if [ -f "$VNC_PASS_FILE" ]; then
    echo
    read -r -p "Encrypted VNC password found. Use saved password? [Y/n]: " use_saved
    use_saved="${use_saved:-Y}"
    if [[ "$use_saved" =~ ^([yY][eE][sS]|[yY])$ ]]; then
      # ask for master passphrase to decrypt
      read -r -s -p "Enter master passphrase to decrypt saved VNC password: " MASTER_PASS
      echo
      if decrypt_password "$MASTER_PASS" >/dev/null 2>&1; then
        VNC_PASS=$(decrypt_password "$MASTER_PASS")
        if [ -z "$VNC_PASS" ]; then
          warn "Decryption returned empty password — proceed to create a new password."
        else
          info "Saved password decrypted successfully."
        fi
      else
        warn "Could not decrypt saved password (wrong passphrase?). You can create a new one."
        VNC_PASS=""
      fi
    fi
  fi

  # If no password set from saved file, prompt/generate and optionally save
  if [ -z "${VNC_PASS}" ]; then
    DEFAULT_PASS=$(randpass)
    read -r -p "Enter VNC password (leave empty to use a secure generated one): " VNC_PASS
    if [ -z "$VNC_PASS" ]; then
      VNC_PASS="$DEFAULT_PASS"
      info "Using generated VNC password: $VNC_PASS"
    else
      info "Using provided VNC password."
    fi

    # Ask whether to save encrypted
    echo
    read -r -p "Save this password encrypted for future runs? [Y/n]: " do_save
    do_save="${do_save:-Y}"
    if [[ "$do_save" =~ ^([yY][eE][sS]|[yY])$ ]]; then
      # require a master passphrase to encrypt
      while true; do
        read -r -s -p "Enter a master passphrase to encrypt the VNC password: " MASTER1
        echo
        read -r -s -p "Confirm master passphrase: " MASTER2
        echo
        if [ "$MASTER1" != "$MASTER2" ]; then
          warn "Passphrases do not match — try again."
        elif [ -z "$MASTER1" ]; then
          warn "Empty passphrase not allowed — try again."
        else
          MASTER_PASS="$MASTER1"
          break
        fi
      done
      # encrypt & save
      if encrypt_password "$VNC_PASS" "$MASTER_PASS"; then
        info "VNC password encrypted and saved to ${VNC_PASS_FILE}."
      else
        warn "Failed to encrypt & save password — openssl may be missing. Falling back to base64 save."
        echo "$VNC_PASS" | base64 > "${VNC_PASS_FILE}.b64"
        chmod 600 "${VNC_PASS_FILE}.b64"
        warn "Saved base64 password to ${VNC_PASS_FILE}.b64 (insecure)."
      fi
    fi
  fi

  # display/port
  read -r -p "Enter VNC display number (default ${DEFAULT_VNC_DISPLAY_NUM} -> port $((5900+DEFAULT_VNC_DISPLAY_NUM))): " VNC_DISPLAY_NUM
  VNC_DISPLAY_NUM="${VNC_DISPLAY_NUM:-${DEFAULT_VNC_DISPLAY_NUM}}"
  VNC_DISPLAY=":${VNC_DISPLAY_NUM}"
  VNC_PORT=$((5900 + VNC_DISPLAY_NUM))
  info "VNC will run on display ${VNC_DISPLAY} (port ${VNC_PORT})."

  # Install TigerVNC (or tightvnc fallback) inside distro
  info "Installing TigerVNC inside ${DIST} (may take a minute)..."
  proot-distro login "${DIST}" -- bash -lc "export DEBIAN_FRONTEND=noninteractive; apt update -y || true; apt install -y tigervnc-standalone-server tigervnc-common || apt install -y tightvncserver || true"

  # Configure VNC password as termuxuser
  info "Configuring VNC password for user 'termuxuser' inside distro..."
  proot-distro login "${DIST}" -- bash -lc "mkdir -p /home/termuxuser/.vnc && chown -R termuxuser:termuxuser /home/termuxuser/.vnc"
  proot-distro login "${DIST}" -- bash -lc "sudo -u termuxuser bash -lc 'printf \"%s\n%s\n\" \"${VNC_PASS}\" \"${VNC_PASS}\" | vncpasswd > /home/termuxuser/.vnc/passwd 2>/dev/null || true; chmod 600 /home/termuxuser/.vnc/passwd' " || warn "Could not run vncpasswd non-interactively (check inside distro)."

  # Kill any existing server on display and start new one
  info "Stopping any existing VNC session on ${VNC_DISPLAY} (if present)..."
  proot-distro login "${DIST}" -- bash -lc "sudo -u termuxuser bash -lc 'vncserver -kill ${VNC_DISPLAY} >/dev/null 2>&1 || true' || true"

  info "Starting VNC server on display ${VNC_DISPLAY} inside distro..."
  proot-distro login "${DIST}" -- bash -lc "sudo -u termuxuser bash -lc 'vncserver ${VNC_DISPLAY} -geometry ${DEFAULT_GEOM} -depth 24 >/home/termuxuser/.vnc/vncserver.log 2>&1 & disown' " || warn "vncserver start may have warnings."

  info "Starting XFCE session inside distro on ${VNC_DISPLAY} (attached to VNC)..."
  proot-distro login "${DIST}" -- bash -lc "sudo -u termuxuser bash -lc 'export DISPLAY=${VNC_DISPLAY}; /home/termuxuser/.xsession >/dev/null 2>&1 & disown' " || warn "Could not start .xsession automatically; you can start inside distro with startxfce4"

  # Detect local IP (best-effort)
  LOCAL_IP=$(get_local_ip)
  VNC_URL="vnc://${LOCAL_IP}:${VNC_PORT}"
  info "VNC server should be up. Attempting to open bVNC automatically -> ${VNC_URL}"

  # Try to open bVNC via Android intent or termux-open-url
  if command -v am >/dev/null 2>&1; then
    am start -a android.intent.action.VIEW -d "${VNC_URL}" >/dev/null 2>&1 || warn "Could not auto-open bVNC; copy-paste URL: ${VNC_URL}"
  elif command -v termux-open-url >/dev/null 2>&1; then
    termux-open-url "${VNC_URL}" >/dev/null 2>&1 || warn "Could not auto-open bVNC; copy-paste URL: ${VNC_URL}"
  else
    warn "No method to auto-open bVNC; use URL: ${VNC_URL}"
  fi

  echo
  info "Connection details:"
  printf "  IP:PORT -> %s:%s\n" "${LOCAL_IP}" "${VNC_PORT}"
  printf "  Display -> %s\n" "${VNC_DISPLAY}"
  printf "  Password -> %s\n" "${VNC_PASS}"
  echo
  info "To stop the VNC server inside distro (run in Termux):"
  echo "  proot-distro login ${DIST} -- bash -lc \"sudo -u termuxuser vncserver -kill ${VNC_DISPLAY}\""
  echo
  info "If the VNC viewer fails to connect to ${LOCAL_IP}, try connecting to 127.0.0.1:${VNC_PORT} or ensure both devices are on the same network."
  exit 0
else
  info "VNC not selected — continuing with other options (Termux:X11 path)."
fi

info "No VNC chosen — exiting. Re-run and select VNC or install Termux:X11."
exit 0
