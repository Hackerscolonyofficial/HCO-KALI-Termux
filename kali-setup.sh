#!/bin/bash
apt update -y
apt upgrade -y

apt install sudo git curl wget nano python3 python3-pip -y
apt install nmap hydra sqlmap metasploit-framework -y
apt install xfce4 xfce4-terminal tightvncserver -y

mkdir -p ~/.vnc
echo "1234" | vncpasswd -f > ~/.vnc/passwd
chmod 600 ~/.vnc/passwd

echo "Kali Setup Completed Successfully!"
