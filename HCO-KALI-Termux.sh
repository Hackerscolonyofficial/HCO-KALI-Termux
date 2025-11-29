#!/data/data/com.termux/files/usr/bin/bash
clear
echo "🔥 Installing HCO-Kali-Termux..."
sleep 2

# Update Termux
pkg update -y && pkg upgrade -y

# Install Required Packages
pkg install proot-distro wget curl git nano -y
pkg install tigervnc -y

# Install Kali Linux RootFS
proot-distro install kali

# Create Auto-Setup Script Inside Kali
cat << 'EOF' > $PREFIX/var/lib/proot-distro/installed-rootfs/kali/root/kali-setup.sh
#!/bin/bash
apt update -y
apt upgrade -y

# Install Basic Tools
apt install sudo git curl wget nano python3 python3-pip -y

# Hacking Tools
apt install nmap hydra sqlmap metasploit-framework -y

# Desktop Environment
apt install xfce4 xfce4-terminal tightvncserver -y

# Set VNC Password (auto: 1234)
mkdir -p ~/.vnc
echo "1234" | vncpasswd -f > ~/.vnc/passwd
chmod 600 ~/.vnc/passwd

echo "Kali Setup Completed Successfully!"
EOF

chmod +x $PREFIX/var/lib/proot-distro/installed-rootfs/kali/root/kali-setup.sh

# Run Auto-Setup Inside Kali
proot-distro login kali -- bash /root/kali-setup.sh

# Create Desktop Start Script
cat << 'EOF' > $PREFIX/bin/kali-desktop
#!/data/data/com.termux/files/usr/bin/bash
proot-distro login kali -- bash -c "vncserver -geometry 1280x720 -localhost no :1"
echo ""
echo "🔥 Kali Linux Desktop is running!"
echo "📌 Open VNC Viewer and connect to: 127.0.0.1:5901"
echo "🔑 Password: 1234"
EOF
chmod +x $PREFIX/bin/kali-desktop

# Create Terminal Launch Shortcut
cat << 'EOF' > $PREFIX/bin/kali
#!/data/data/com.termux/files/usr/bin/bash
proot-distro login kali
EOF
chmod +x $PREFIX/bin/kali

echo ""
echo "✅ HCO-Kali-Termux Installed Successfully!"
echo "----------------------------------------"
echo "➡ Start Kali Terminal:    kali"
echo "➡ Start GUI Desktop:      kali-desktop"
echo "➡ VNC Password:           1234"
echo "----------------------------------------"
