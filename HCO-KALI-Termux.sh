#!/data/data/com.termux/files/usr/bin/bash
# HCO-KALI-TERMUX
# Code by Azhar • Team HCO

YOUTUBE_LINK="https://youtube.com/@hackers_colony_tech?sub_confirmation=1"

clear
echo -e "\e[1m\e[96mHCO-KALI-TERMUX INSTALLER\e[0m"
echo -e "\e[1m\e[92mCode by Azhar • Hackers Colony\e[0m\n"
sleep 1

# ------------------------------- #
#        TOOL LOCK – YOUTUBE
# ------------------------------- #

echo -e "\e[1m\e[93mThis tool requires SUBSCRIPTION to continue.\e[0m"
echo -e "\e[1m\e[96mRedirecting to Hackers Colony Tech in 10 seconds...\e[0m\n"

for i in {10..1}
do
    echo -e "\e[1m\e[91mPlease wait: $i\e[0m"
    sleep 1
done

termux-open-url "$YOUTUBE_LINK"

read -p $'\n\e[1m\e[92mAfter subscribing press ENTER to continue...\e[0m'

clear
echo -e "\e[1m\e[92m✔ Subscription confirmed!\e[0m"
sleep 1
clear

# ------------------------------- #
#       START INSTALLATION
# ------------------------------- #

echo -e "\e[1m\e[96mUpdating Termux...\e[0m"
pkg update -y && pkg upgrade -y

echo -e "\e[1m\e[96mInstalling required packages...\e[0m"
pkg install wget proot-distro proot tar xfce4 tigervnc -y


# ------------------------------- #
#       INSTALL KALI LINUX
# ------------------------------- #

clear
echo -e "\e[1m\e[93mInstalling Kali Linux...\e[0m"
proot-distro install kali

echo -e "\e[1m\e[92m✔ Kali Installed Successfully!\e[0m"


# ------------------------------- #
#     CONFIGURE XFCE DESKTOP
# ------------------------------- #

echo -e "\e[1m\e[96mSetting up XFCE GUI...\e[0m"

proot-distro login kali -- bash -c "
apt update -y
apt install xfce4 xfce4-goodies dbus-x11 sudo -y
"


# ------------------------------- #
#        VNC START FILE
# ------------------------------- #

mkdir -p $HOME/.vnc

cat > $HOME/.vnc/start-kali.sh << 'EOF'
#!/bin/bash
export DISPLAY=:1
vncserver -kill :1 >/dev/null 2>&1
vncserver -geometry 1280x720 -depth 24 :1
EOF

chmod +x $HOME/.vnc/start-kali.sh


# ------------------------------- #
#       KALI INTERNAL VNC
# ------------------------------- #

proot-distro login kali -- bash -c '
echo "
#!/bin/bash
export DISPLAY=:1
startxfce4 &
" > /root/.vnc/xstartup
chmod +x /root/.vnc/xstartup
'


# ------------------------------- #
#           LAUNCHER
# ------------------------------- #

cat > $PREFIX/bin/hco-kali << 'EOF'
#!/data/data/com.termux/files/usr/bin/bash
echo -e "\e[1m\e[96mStarting VNC Server on :1 ...\e[0m"
bash $HOME/.vnc/start-kali.sh
echo -e "\e[1m\e[92mOpen VNC Viewer → 127.0.0.1:1\e[0m"
echo -e "\e[1m\e[93mUsername: root\e[0m"
echo -e "\e[1m\e[93mPassword: kali\e[0m"
proot-distro login kali
EOF

chmod +x $PREFIX/bin/hco-kali


# ------------------------------- #
#       SET VNC PASSWORD
# ------------------------------- #

proot-distro login kali -- bash -c "
mkdir -p /root/.vnc
echo 'kali' | vncpasswd -f > /root/.vnc/passwd
chmod 600 /root/.vnc/passwd
"


# ------------------------------- #
#          FINISHED!
# ------------------------------- #

clear
echo -e "\e[1m\e[92m✔ HCO-KALI-TERMUX Installed Successfully!\e[0m"
echo -e "\e[1m\e[96mStart Kali anytime by typing:\e[0m"
echo -e "\e[1m\e[91m     hco-kali\e[0m"
echo -e "\n\e[1m\e[93mVNC Address: 127.0.0.1:1\e[0m"
echo -e "\e[1m\e[93mVNC Password: kali\e[0m"
echo -e "\n\e[1m\e[96mEnjoy Full GUI Kali Linux in Termux!\e[0m"
