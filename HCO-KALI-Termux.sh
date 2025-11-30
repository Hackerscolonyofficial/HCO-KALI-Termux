#!/data/data/com.termux/files/usr/bin/bash
clear

echo "🔥 HCO-Kali-Termux Installer"
sleep 1

# Update packages
pkg update -y && pkg upgrade -y
pkg install wget curl proot-distro nano git tigervnc -y

# Create profile directory
mkdir -p $PREFIX/etc/proot-distro/

# Create custom Kali profile (Auto Fix)
cat > $PREFIX/etc/proot-distro/kali.sh << 'EOF'
DISTRO_NAME="Kali Linux (HCO Profile)"
DISTRO_ARCH="aarch64"

TARBALL_URL['aarch64']="https://kali.download/nethunter-images/current/rootfs/kalifs-arm64-full.tar.xz"
TARBALL_SHA256['aarch64']="skip"

EXTRACT_USING="tar"

DISTRO_SETUP_COMMANDS=(
  "apt update -y"
  "apt upgrade -y"
)
EOF

echo "✔ Kali profile created."

echo "🔥 Installing Kali Linux..."
sleep 1
proot-distro install kali

echo "✔ Installing Desktop + Tools inside Kali..."

# Create setup script inside Kali
cat > $PREFIX/var/lib/proot-distro/installed-rootfs/kali/root/kali-setup.sh << 'EOF'
#!/bin/bash

apt update -y
apt upgrade -y

apt install sudo git curl wget nano python3 python3-pip -y
apt install xfce4 xfce4-terminal tightvncserver dbus-x11 -y
apt install nmap hydra sqlmap metasploit-framework -y

mkdir -p ~/.vnc
echo "1234" | vncpasswd -f > ~/.vnc/passwd
chmod 600 ~/.vnc/passwd

echo "✔ Kali Setup Complete!"
EOF

chmod +x $PREFIX/var/lib/proot-distro/installed-rootfs/kali/root/kali-setup.sh

# Run inside Kali
proot-distro login kali -- bash /root/kali-setup.sh

# Create desktop start command
cat > $PREFIX/bin/kali-desktop << 'EOF'
#!/data/data/com.termux/files/usr/bin/bash
proot-distro login kali -- bash -c "vncserver -geometry 1280x720 -localhost no :1"
echo ""
echo "🔥 Kali Linux Desktop Running!"
echo "Open VNC Viewer: 127.0.0.1:5901"
echo "Password: 1234"
EOF

chmod +x $PREFIX/bin/kali-desktop

# Create terminal shortcut
cat > $PREFIX/bin/kali << 'EOF'
#!/data/data/com.termux/files/usr/bin/bash
proot-distro login kali
EOF

chmod +x $PREFIX/bin/kali

echo ""
echo "🎉 HCO-KALI-Termux Installed Successfully!"
echo "----------------------------------------"
echo "Kali Terminal      → kali"
echo "Kali GUI Desktop   → kali-desktop"
echo "VNC Password       → 1234"
echo "----------------------------------------"
