#!/data/data/com.termux/files/usr/bin/bash
# HCO-Kali-Termux
# by Hackers Colony (Azhar)

clear

YOUTUBE_LINK="https://youtube.com/@hackers_colony_tech?si=pvdCWZggTIuGb0ya"

banner() {
clear
echo -e "\e[91m
██╗  ██╗ ██████╗  ██████╗     ██╗  ██╗ █████╗ ██╗  ██╗███████╗██████╗ 
██║  ██║██╔═══██╗██╔════╝     ██║  ██║██╔══██╗██║ ██╔╝██╔════╝██╔══██╗
███████║██║   ██║██║  ███╗    ███████║███████║█████╔╝ █████╗  ██████╔╝
██╔══██║██║   ██║██║   ██║    ██╔══██║██╔══██║██╔═██╗ ██╔══╝  ██╔══██╗
██║  ██║╚██████╔╝╚██████╔╝    ██║  ██║██║  ██║██║  ██╗███████╗██║  ██║
╚═╝  ╚═╝ ╚═════╝  ╚═════╝     ╚═╝  ╚═╝╚═╝  ╚═╝╚═╝  ╚═╝╚══════╝╚═╝  ╚═╝
\e[0m"
echo -e "\e[92m       🚀 HCO-Kali-Termux | Kali Linux with GUI (XFCE)\e[0m"
echo ""
}

# ─────────────────────────────────────────────
# 1. YOUTUBE REDIRECT + TOOL LOCK
# ─────────────────────────────────────────────
banner
echo -e "\e[93mThis tool is NOT FREE.\e[0m"
echo -e "\e[91mYou MUST subscribe to Hackers Colony Tech to continue.\e[0m"
echo ""
echo -e "\e[96mRedirecting to YouTube in 7 seconds...\e[0m"
sleep 7

termux-open-url "$YOUTUBE_LINK"
sleep 2

banner
read -p $'\e[92mAfter Subscribing, press ENTER to continue… \e[0m' ok

# ─────────────────────────────────────────────
# 2. INSTALL DEPENDENCIES
# ─────────────────────────────────────────────
banner
echo -e "\e[96m[+] Updating Termux packages...\e[0m"
pkg update -y && pkg upgrade -y

echo -e "\e[96m[+] Installing required packages...\e[0m"
pkg install -y proot-distro wget pulseaudio xfce4 tigervnc

# ─────────────────────────────────────────────
# 3. INSTALL KALI LINUX (MINIMAL)
# ─────────────────────────────────────────────
banner
echo -e "\e[96m[+] Installing Kali Linux (Minimal)...\e[0m"
proot-distro install kali

# ─────────────────────────────────────────────
# 4. SETUP GUI + XFCE INSIDE KALI
# ─────────────────────────────────────────────
banner
echo -e "\e[96m[+] Configuring XFCE GUI...\e[0m"

proot-distro login kali -- bash -c "
apt update -y
apt install -y xfce4 xfce4-terminal dbus-x11 tigervnc-standalone-server
"

# ─────────────────────────────────────────────
# 5. AUTO CONFIGURE VNC + FIX BLACK SCREEN
# ─────────────────────────────────────────────
banner
echo -e "\e[96m[+] Setting up VNC server...\e[0m"

cat > ~/.vnc/xstartup <<EOF
#!/bin/bash
xrdb $HOME/.Xresources
startxfce4 &
EOF
chmod +x ~/.vnc/xstartup

# Black screen fix
echo "unset SESSION_MANAGER" >> ~/.vnc/xstartup
echo "unset DBUS_SESSION_BUS_ADDRESS" >> ~/.vnc/xstartup

# ─────────────────────────────────────────────
# 6. CREATE LAUNCHER COMMANDS
# ─────────────────────────────────────────────

cat > start-kali <<EOF
#!/data/data/com.termux/files/usr/bin/bash
pulseaudio --start --exit-idle-time=-1
export PULSE_SERVER=127.0.0.1
proot-distro login kali -- bash
EOF
chmod +x start-kali

cat > start-kali-gui <<EOF
#!/data/data/com.termux/files/usr/bin/bash
export DISPLAY=:1
vncserver -geometry 1280x720 :1
echo ""
echo "🔥 GUI Started!"
echo "👉 Open VNC Viewer"
echo "👉 Address: 127.0.0.1:5901"
echo "👉 Password: (your VNC password)"
echo ""
EOF
chmod +x start-kali-gui

cat > stop-kali-gui <<EOF
#!/data/data/com.termux/files/usr/bin/bash
vncserver -kill :1
EOF
chmod +x stop-kali-gui

# ─────────────────────────────────────────────
# 7. FINISHED
# ─────────────────────────────────────────────

banner
echo -e "\e[92m🎉 Installation Complete!\e[0m"
echo ""
echo -e "\e[96mRun Kali Terminal:\e[0m"
echo -e "\e[92m   ./start-kali\e[0m"
echo ""
echo -e "\e[96mRun Kali GUI (XFCE):\e[0m"
echo -e "\e[92m   ./start-kali-gui\e[0m"
echo ""
echo -e "\e[96mStop GUI:\e[0m"
echo -e "\e[92m   ./stop-kali-gui\e[0m"
echo ""
echo -e "\e[95m🔥 Enjoy full Kali Linux desktop in Termux!\e[0m"
