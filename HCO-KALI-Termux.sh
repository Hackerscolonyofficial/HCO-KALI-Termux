#!/data/data/com.termux/files/usr/bin/bash
clear

# --------------------------
# Simple, monospace-safe banner
# --------------------------
echo "=============================================="
echo "             HCO-KALI-TERMUX Installer        "
echo "                Code by Azhar                 "
echo "=============================================="
echo ""

sleep 1

# Check required file
if [ ! -f "kali-profile.sh" ]; then
  echo "❌ ERROR: Missing file 'kali-profile.sh' in this folder."
  echo "Please place kali-profile.sh next to this installer and rerun."
  exit 1
fi

echo "🔹 Updating packages..."
pkg update -y && pkg upgrade -y

echo "🔹 Installing dependencies..."
pkg install wget curl git nano proot-distro tigervnc -y

echo "🔹 Copying Kali profile..."
mkdir -p $PREFIX/etc/proot-distro/
cp kali-profile.sh $PREFIX/etc/proot-distro/kali.sh

echo ""
echo "🔹 Installing Kali Linux RootFS (this may take a while)..."
proot-distro install kali
if [ $? -ne 0 ]; then
  echo ""
  echo "❌ Kali installation failed. Common fixes:"
  echo "  • Ensure your internet connection is stable."
  echo "  • Make sure the URL inside kali-profile.sh is reachable."
  echo "  • Try: pkg update -y && pkg install proot-distro -y"
  exit 1
fi

echo ""
echo "🔹 Setting up Kali Linux tools (inside Kali)..."
cat > $PREFIX/var/lib/proot-distro/installed-rootfs/kali/root/kali-setup.sh << 'EOF'
#!/bin/bash
set -e

apt update -y
apt upgrade -y

# Basic utilities
apt install sudo git curl wget nano python3 python3-pip -y

# Desktop and VNC
apt install xfce4 xfce4-terminal tightvncserver dbus-x11 -y

# Common pentest tools (installing some may take time)
apt install nmap hydra sqlmap metasploit-framework -y || true

# Setup VNC password (1234)
mkdir -p ~/.vnc
echo "1234" | vncpasswd -f > ~/.vnc/passwd
chmod 600 ~/.vnc/passwd

echo "✔ Kali Setup Complete!"
EOF

chmod +x $PREFIX/var/lib/proot-distro/installed-rootfs/kali/root/kali-setup.sh

# Run setup inside Kali
proot-distro login kali -- bash /root/kali-setup.sh

echo ""
echo "🔹 Creating desktop launcher script (kali-desktop)..."
cat > $PREFIX/bin/kali-desktop << 'EOF'
#!/data/data/com.termux/files/usr/bin/bash
proot-distro login kali -- bash -c "vncserver -geometry 1280x720 -localhost no :1"
echo ""
echo "🔥 Kali Linux Desktop Started!"
echo "➡ Open VNC Viewer → 127.0.0.1:5901"
echo "➡ Password → 1234"
EOF
chmod +x $PREFIX/bin/kali-desktop

echo "🔹 Creating terminal launcher (kali)..."
cat > $PREFIX/bin/kali << 'EOF'
#!/data/data/com.termux/files/usr/bin/bash
proot-distro login kali
EOF
chmod +x $PREFIX/bin/kali

echo ""
echo "=============================================="
echo "🎉 HCO-KALI-TERMUX Installed Successfully!"
echo "----------------------------------------------"
echo "• Start Kali Terminal : kali"
echo "• Start Kali Desktop  : kali-desktop"
echo "• VNC Viewer Address  : 127.0.0.1:5901"
echo "• VNC Password        : 1234"
echo "----------------------------------------------"
echo "✔ Code by Azhar"
echo "✔ \"Hackers don't break systems — they break limits.\""
echo "=============================================="
