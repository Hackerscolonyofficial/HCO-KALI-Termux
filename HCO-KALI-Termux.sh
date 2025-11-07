#!/usr/bin/env bash
# HCO-KALI-Termux.sh — real VNC server (fixed, robust)
# Author: Azhar | Hackers Colony
# Usage: chmod +x HCO-KALI-Termux.sh && ./HCO-KALI-Termux.sh

set -euo pipefail
DEBUG=1

# ---------- Config ----------
YOUTUBE_URL="https://youtube.com/@hackers_colony_tech?si=pvdCWZggTIuGb0ya"
PREFERRED="kali"
FALLBACK="debian"
BOOTSTRAP_FLAG="${HOME}/.hco_kali_bootstrap_done"
PREFIX="${PREFIX:-/data/data/com.termux/files/usr}"
START_WRAPPER="${HOME}/start-vnc"     # wrapper created at end
DIST_USER="termuxuser"
VNC_DISPLAY_NUM=1
VNC_PORT=$((5900 + VNC_DISPLAY_NUM))
VNC_PASS_FILE="${HOME}/.hco_vnc_pass"

info(){ printf "\e[1;36m[INFO]\e[0m %s\n" "$*"; }
warn(){ printf "\e[1;33m[WARN]\e[0m %s\n" "$*"; }
err(){ printf "\e[1;31m[ERR]\e[0m %s\n" "$*"; exit 1; }

detect_arch(){ uname -m || echo "unknown"; }

# ---------- YouTube lock (unchanged) ----------
clear
echo -e "\e[1;33m🔒 TOOL LOCKED — HCO-KALI-Termux\e[0m"
echo "Subscribe to Hackers Colony Tech on YouTube and click the bell."
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
read -r -p $'\nPress ENTER when you are back in Termux to continue: '

# ---------- Ensure proot-distro exists on host ----------
info "Ensuring proot-distro is installed in Termux..."
pkg update -y || warn "pkg update failed"
pkg install -y proot-distro wget curl coreutils util-linux git openssl || true
command -v proot-distro >/dev/null 2>&1 || err "proot-distro not available — install Termux (F-Droid) and try again."

# ---------- Create distro profile (if missing) ----------
if ! proot-distro list | grep -Eqi "^(${PREFERRED}|${FALLBACK})"; then
  info "No distro profiles found — creating ${PREFERRED} profile (if tarball available)..."
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
DISTRO_COMMENT="Kali Linux custom profile"
TARBALL_URL="${TARBALL_URL}"
TARBALL_SHA256=""
EOF
    info "Custom profile created: ${PREFIX}/etc/proot-distro/${PREFERRED}.sh"
  else
    warn "No suitable tarball for arch ${arch}. Will rely on default distro list and fallback."
  fi
fi

# ---------- Install distro (non-interactive) ----------
DIST="$PREFERRED"
info "Installing distro '${DIST}' (may take a while)..."
set +e
echo "y" | proot-distro install "$DIST" >/dev/null 2>&1
rc=$?
set -e
if [ $rc -ne 0 ]; then
  warn "Install of ${DIST} failed or was noisy — attempting fallback '${FALLBACK}'."
  DIST="$FALLBACK"
  echo "y" | proot-distro install "$DIST" >/dev/null 2>&1 || err "Failed to install fallback distro '${FALLBACK}'. Check network/storage."
fi
info "Using distro: ${DIST}"

# ---------- Bootstrap: install Xvfb, x11vnc, tightvnc fallback, create user ----------
if [ ! -f "$BOOTSTRAP_FLAG" ]; then
  info "Bootstrapping packages inside distro (Xvfb, x11vnc, tightvnc fallback) and creating user '${DIST_USER}'..."
  TMP=$(mktemp)
  cat > "$TMP" <<'EOBOOT'
#!/usr/bin/env bash
set -e
export DEBIAN_FRONTEND=noninteractive

# update + installs (inside distro)
apt update -y || true
apt upgrade -y || true

# Preferred: x11vnc + Xvfb; ensure vncpasswd is available (provided by tightvncserver)
apt install -y xvfb x11vnc tightvncserver x11-xkb-utils openbox lxde-core lxterminal sudo net-tools || true

# create user if missing
if ! id -u termuxuser >/dev/null 2>&1; then
  useradd -m -s /bin/bash termuxuser || true
  echo "termuxuser:termux" | chpasswd || true
  usermod -aG sudo termuxuser || true
fi

# ensure home exists & permissions
mkdir -p /home/termuxuser
chown -R termuxuser:termuxuser /home/termuxuser || chown -R termuxuser:root /home/termuxuser || true

echo "BOOTSTRAP_DONE"
EOBOOT

  proot-distro login "$DIST" -- bash -s < "$TMP" || warn "Bootstrap inside distro finished with warnings."
  rm -f "$TMP"
  touch "$BOOTSTRAP_FLAG"
  info "Bootstrap finished."
else
  info "Bootstrap already completed (flag present)."
fi

# ---------- Ensure VNC utilities present inside distro ----------
info "Verifying VNC utilities inside distro..."
proot-distro login "$DIST" -- bash -lc "command -v Xvfb >/dev/null 2>&1 && command -v x11vnc >/dev/null 2>&1 && command -v vncpasswd >/dev/null 2>&1" || {
  warn "VNC utilities not fully present; attempting to install inside distro again."
  proot-distro login "$DIST" -- bash -lc "export DEBIAN_FRONTEND=noninteractive; apt update -y || true; apt install -y xvfb x11vnc tightvncserver || true"
}

# ---------- Prepare VNC password on host-side (will write inside distro) ----------
if [ -f "$VNC_PASS_FILE" ]; then
  VNC_PASS="$(cat "$VNC_PASS_FILE")"
  info "Using existing saved VNC password (from $VNC_PASS_FILE)."
else
  VNC_PASS="$(openssl rand -base64 12 | tr -dc 'A-Za-z0-9' | head -c 12)"
  echo "$VNC_PASS" > "$VNC_PASS_FILE"
  chmod 600 "$VNC_PASS_FILE"
  info "Generated & saved VNC password to $VNC_PASS_FILE"
fi

# ---------- Create start-vnc wrapper (robust) ----------
cat > "$START_WRAPPER" <<'BASH'
#!/usr/bin/env bash
set -euo pipefail
DIST_PLACEHOLDER="__DIST__"
USER="termuxuser"
VNC_DISPLAY=":__VD__"
VNC_PORT=__VP__
VNC_PASS="__VPASS__"

info(){ printf "\e[1;36m[INFO]\e[0m %s\n" "$*"; }
warn(){ printf "\e[1;33m[WARN]\e[0m %s\n" "$*"; }

info "Starting Xvfb and x11vnc inside ${DIST_PLACEHOLDER}..."

# 1) start Xvfb as termuxuser
proot-distro login "${DIST_PLACEHOLDER}" -- bash -lc "sudo -u ${USER} Xvfb ${VNC_DISPLAY} -screen 0 1280x720x16 >/tmp/xvfb_${USER}.log 2>&1 & echo \$! > /tmp/xvfb_${USER}.pid" || warn "Failed to launch Xvfb (check /tmp/xvfb_${USER}.log inside distro)."

# small wait for Xvfb to initialize
sleep 2

# 2) ensure .vnc dir and write password file using vncpasswd (non-interactive)
proot-distro login "${DIST_PLACEHOLDER}" -- bash -lc "
sudo -u ${USER} mkdir -p /home/${USER}/.vnc
# create passwd using vncpasswd -f (tightvnc)
printf '%s\n%s\n' \"${VNC_PASS}\" \"${VNC_PASS}\" | sudo -u ${USER} vncpasswd -f > /home/${USER}/.vnc/passwd 2>/dev/null || true
# as fallback, try x11vnc -storepasswd (some installs)
if [ ! -s /home/${USER}/.vnc/passwd ]; then
  printf '%s\n' \"${VNC_PASS}\" | sudo -u ${USER} x11vnc -storepasswd -f /home/${USER}/.vnc/passwd 2>/dev/null || true
fi
chmod 600 /home/${USER}/.vnc/passwd || true
chown -R ${USER}:${USER} /home/${USER}/.vnc 2>/dev/null || chown -R ${USER}:root /home/${USER}/.vnc 2>/dev/null || true
"

# Verify passwd exists inside distro
if ! proot-distro login "${DIST_PLACEHOLDER}" -- bash -lc "test -s /home/${USER}/.vnc/passwd"; then
  warn "VNC password file not created inside distro. Please run: proot-distro login ${DIST_PLACEHOLDER} -- bash and run 'sudo -u ${USER} vncpasswd' interactively and retry."
  exit 1
fi

# 3) Stop any existing x11vnc on that display, then start it (bind 0.0.0.0)
proot-distro login "${DIST_PLACEHOLDER}" -- bash -lc "
sudo -u ${USER} pkill -f 'x11vnc -display ${VNC_DISPLAY}' >/dev/null 2>&1 || true
sudo -u ${USER} x11vnc -display ${VNC_DISPLAY} -rfbport ${VNC_PORT} -rfbauth /home/${USER}/.vnc/passwd -forever -shared -bg -listen 0.0.0.0 >/home/${USER}/.vnc/x11vnc.log 2>&1 || true
"

# small wait
sleep 2

# Check x11vnc running
if proot-distro login "${DIST_PLACEHOLDER}" -- bash -lc "pgrep -a x11vnc >/dev/null 2>&1"; then
  info "x11vnc appears to be running inside distro."
else
  warn "x11vnc not detected running. Check logs inside distro: /home/${USER}/.vnc/x11vnc.log"
  exit 1
fi

# detect Termux host IP (best-effort)
HOST_IP=$(ip addr show wlan0 2>/dev/null | awk '/inet /{print $2; exit}' | cut -d/ -f1)
HOST_IP=${HOST_IP:-127.0.0.1}

echo
info "VNC server should now be reachable from this device."
echo "Connect any VNC client to: ${HOST_IP}:${VNC_PORT}"
echo "Display (distro): ${VNC_DISPLAY}"
echo "Password: ${VNC_PASS}"
BASH

# replace placeholders
sed -i "s|__DIST__|${DIST}|g" "$START_WRAPPER"
sed -i "s|__VD__|${VNC_DISPLAY_NUM}|g" "$START_WRAPPER"
sed -i "s|__VP__|${VNC_PORT}|g" "$START_WRAPPER"
# escape possible slashes in password (should be safe, but we will use printf replacement)
escaped_pass="$(printf %s "$VNC_PASS" | sed 's/[\/&]/\\&/g')"
sed -i "s|__VPASS__|${escaped_pass}|g" "$START_WRAPPER"
chmod +x "$START_WRAPPER"

info "Wrapper created at: $START_WRAPPER"

# ---------- Ask user to start VNC server now ----------
read -r -p $'\nStart the VNC server now? [Y/n]: ' ans
ans="${ans:-Y}"
if [[ "$ans" =~ ^([yY][eE][sS]|[yY])$ ]]; then
  bash "$START_WRAPPER" || err "Failed to start VNC server wrapper. Inspect wrapper or run the wrapper manually for debug."
else
  info "You can start it later with: $START_WRAPPER"
fi

info "All done. If connection still fails, inspect the VNC logs inside the distro:"
info "  proot-distro login ${DIST} -- bash -lc 'cat /home/${DIST_USER}/.vnc/x11vnc.log'"
