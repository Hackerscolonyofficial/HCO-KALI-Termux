# 🐉 HCO-KALI-Termux by Azhar

[![YouTube](https://img.shields.io/badge/YouTube-HackersColony-red?logo=youtube&style=for-the-badge)](https://youtube.com/@hackers_colony_tech?si=pvdCWZggTIuGb0ya)  
[![Telegram](https://img.shields.io/badge/Telegram-Join-blue?logo=telegram&style=for-the-badge)](https://t.me/hackersColony)  
[![Discord](https://img.shields.io/badge/Discord-Join-purple?logo=discord&style=for-the-badge)](https://discord.gg/Xpq9nCGD)  
[![Instagram](https://img.shields.io/badge/Instagram-Follow-pink?logo=instagram&style=for-the-badge)](https://www.instagram.com/hackers_colony_official)  
[![Facebook](https://img.shields.io/badge/Facebook-Like-blue?logo=facebook&style=for-the-badge)](https://www.facebook.com/share/1AY25it2Em/)

---

## ⚡ About

**HCO-KALI-Termux** is a single-file installer that prepares a Kali-like environment inside Termux using `proot-distro` and bootstraps a lightweight **XFCE** desktop prepared for **Termux:X11** (Termux X server).  
The installer will:

- install a Kali profile (or Debian fallback) via `proot-distro`,  
- bootstrap XFCE and a non-root user (`termuxuser`),  
- create a convenient `~/start-xfce` wrapper,  
- **prompt you** at the end: “Do you want to open Termux:X11 now?” — only if you answer **Yes** will it attempt to open the Termux:X11 app and start XFCE. (No auto-launch without your consent.)

---

## ✅ Features

- ✅ No root required — runs inside Termux using `proot-distro`.  
- ✅ Attempts Kali profile per device architecture; falls back to Debian if needed.  
- ✅ Installs a lightweight XFCE desktop environment inside the chroot.  
- ✅ Creates `~/start-xfce` wrapper for one-command desktop start (requires Termux:X11).  
- ✅ Explicit user prompt before any GUI auto-launch.  
- ✅ Helpful troubleshooting messages & clear manual commands.

---

## 🧰 Requirements (before running)

1. Termux (prefer F-Droid build) installed on Android.  
2. Internet connection (downloads several hundred MB — multiple GB possible).  
3. Enough free storage (recommend **≥ 6 GB** for comfortable use).  
4. (Optional for GUI) Termux:X11 app installed — if you want GUI, install Termux:X11 from its GitHub releases or F-Droid.  
   - Termux:X11 releases: https://github.com/termux/termux-x11/releases

---

## 📦 Install & Run — step by step

Copy the script into Termux (recommended) and run it:

```bash
# 1) create file and paste the installer (recommended via nano)
cd ~
nano HCO-KALI-Termux.sh
# Paste the installer script contents into nano, save (Ctrl+O) and exit (Ctrl+X)

# 2) make the installer executable
chmod +x ~/HCO-KALI-Termux.sh

# 3) run the installer
bash ~/HCO-KALI-Termux.sh

```
🔎 What happens when you run it

1. The script shows a 🔒 unlock prompt and opens the Hackers Colony YouTube link.


2. After you press ENTER, it installs proot-distro (if needed), creates or uses an existing Kali profile (or Debian fallback), and bootstraps XFCE + a termuxuser.


3. It creates ~/start-xfce (executable wrapper) for future use.


4. At the end you are asked:
Open Termux:X11 now? [y/N]

If you answer Yes, the script attempts to open the Termux:X11 app (if installed) and runs ~/start-xfce to start XFCE in the X server.

If you answer No, nothing GUI-related is auto-launched; the script prints the exact manual command to start the GUI later.





---

▶️ Start GUI later (manual)

Make sure you have launched the Termux:X11 app (the X server) on your Android device, then run:

# start XFCE (wrapper created by installer)
~/start-xfce

Or with an explicit proot command:

proot-distro login <distro-alias> -- bash -lc "export DISPLAY=:0; sudo -u termuxuser /home/termuxuser/.xsession &"

> Replace <distro-alias> with kali or debian depending on which the installer created — the script prints which distro it installed.




---

🛠 Useful commands

Login into the chroot:


proot-distro login kali        # or 'debian' if fallback used

Re-run bootstrap (if you want to reapply XFCE setup):


# use the bootstrap commands from the installer inside the distro
proot-distro login <distro> -- bash
# then run apt update && apt install xfce4 ...

Remove distro (clean install):


proot-distro remove kali       # or debian


---

🔧 Troubleshooting

Not enough space: free internal storage or add external storage.

Termux:X11 not installed: installer will open the Termux:X11 releases page; install it and run ~/start-xfce.

Desktop not visible: ensure Termux:X11 is running and DISPLAY is :0. Launch Termux:X11 app before running ~/start-xfce.

Slow UI: lower desktop visual effects or use smaller display resolution in XFCE settings. Close other memory-heavy apps.



---

🔐 Security & Disclaimer (READ CAREFULLY)

For educational & lab use only. Do not use this tool to access systems you do not own or have permission to test.

The script attempts to help you run a Kali-like environment inside Termux — you are responsible for how you use it.

GUI opening is performed only after explicit user confirmation — the script will not auto-open Termux:X11 without your consent.

Always secure any exposed services (don’t expose X server or any ports to public networks).

Hackers Colony and the author Azhar are not responsible for misuse. Use ethically and legally.


###👨‍💻 CODE by Azhar
---

🧾 License

This project is provided as-is for learning and lab use. Add an appropriate license (e.g., MIT) in your repo root if you plan to publish.


---

💬 Hacker Quote

> “Playing with Systems, not Hearts.” — Hackers Colony
