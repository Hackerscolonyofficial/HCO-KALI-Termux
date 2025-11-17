#!/usr/bin/env bash
# HCO-KALI-TERMUX.sh — Full Kali XFCE GUI Installer (aarch64)
# Author: Azhar | Hackers Colony

set -euo pipefail
ARCH=$(dpkg --print-architecture)

echo "--------------------------------------------"
echo "     HCO Kali Linux XFCE Installer"
echo "        Author: Azhar | Hackers Colony"
echo "--------------------------------------------"
sleep 2

# ---------- ROOTFS URL ----------
case "$ARCH" in
    aarch64)
        ROOTFS_URL="https://kali.download/nethunter-images/kali-2023.3/rootfs/kalifs-arm64-full.tar.xz"
        ;;
    *)
        echo "[!] Unsupported CPU architecture: $ARCH"
        exit 1
        ;;
esac

# ---------- PACKAGE SETUP ----------
pkg update -y && pkg upgrade -y
pkg install proot-distro wget tar pulseaudio termux-x11-nightly -y

# ---------- DOWNLOAD ROOTFS ----------
mkdir -p $PREFIX/var/lib/proot-distro/tarballs
cd $PREFIX/var/lib/proot-distro/tarballs

echo "[+] Downloading Kali rootfs..."
wget -O kali-rootfs.tar.xz "$ROOTFS_URL"

# ---------- INSTALL KALI ----------
echo "[+] Installing Kali Linux..."
proot-distro install --override-alias kali kali-rootfs.tar.xz

# ---------- CONFIGURE GUI ----------
KALI_ROOTFS="$PREFIX/var/lib/proot-distro/installed-rootfs/kali"

mkdir -p "$KALI_ROOTFS/root"

cat << 'EOF' > "$KALI_ROOTFS/root/start-xfce.sh"
#!/bin/bash
export DISPLAY=:0
export PULSE_SERVER=127.0.0.1
pulseaudio --start
startxfce4
EOF

chmod +x "$KALI_ROOTFS/root/start-xfce.sh"

# ---------- INSTALL XFCE DESKTOP ----------
echo "[+] Installing XFCE Desktop..."
proot-distro login kali -- << 'EOF'
apt update
apt install xfce4 xfce4-goodies kali-themes dbus-x11 tigervnc-standalone-server -y
apt install firefox-esr neofetch git curl wget nmap zip unzip nano -y
EOF

# ---------- CREATE DESKTOP STARTER ----------
cat > $PREFIX/bin/kali-xfce << 'EOF'
#!/bin/bash
termux-x11 :0 >/dev/null 2>&1 &
sleep 2
proot-distro login kali -- ./root/start-xfce.sh
EOF

chmod +x $PREFIX/bin/kali-xfce

echo ""
echo "--------------------------------------------"
echo " ✔ Kali Linux XFCE Installed Successfully!"
echo "--------------------------------------------"
echo " Start the GUI Desktop:"
echo "     kali-xfce"
echo "--------------------------------------------"
echo " Code by Azhar | Hackers Colony"
echo "--------------------------------------------"
