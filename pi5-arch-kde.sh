#!/usr/bin/env bash
# Maintainer: @knilix
# ============================================================
# Script 2: alarm-rpi5-setup.sh
# Läuft auf dem Raspberry Pi 5 (als root via SSH).
# Richtet Arch Linux ARM mit KDE Plasma 6 ein.
# ============================================================

# Terminal-Pufferung deaktivieren
exec 1> >(stdbuf -o0 cat) 2>&1

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}Dieses Script muss als root ausgeführt werden.${NC}"
    exit 1
fi

echo ""
echo -e "${GREEN}=== Arch Linux ARM – Raspberry Pi 5 – Einrichtung ===${NC}"
echo ""

# ============================================================
echo -e "${GREEN}[1/17] SSH-Dienst aktivieren ...${NC}"
systemctl enable sshd

# ============================================================
echo -e "${GREEN}[2/17] Pacman-Schlüssel initialisieren ...${NC}"
pacman-key --init
pacman-key --populate archlinuxarm

# ============================================================
echo -e "${GREEN}[3/17] Pi 5 Kernel & Firmware wechseln ...${NC}"
# Alten Pi 4 Kernel deinstallieren und echten 16k Pi 5 Kernel holen
pacman -Rns --noconfirm linux-rpi
pacman -Sy --noconfirm linux-rpi-16k raspberrypi-bootloader raspberrypi-firmware

# ============================================================
echo -e "${GREEN}[4/17] Temporären Pi 5 Boot-Workaround entfernen ...${NC}"
sed -i '/kernel=kernel8.img/d' /boot/config.txt

# ============================================================
echo -e "${GREEN}[5/17] Hostname setzen ...${NC}"
echo "arch-arm" > /etc/hostname

# ============================================================
echo -e "${GREEN}[6/17] Locale setzen ...${NC}"
sed -i 's/^#de_DE.UTF-8/de_DE.UTF-8/' /etc/locale.gen
locale-gen
echo "LANG=de_DE.UTF-8" > /etc/locale.conf
echo "KEYMAP=de-latin1" > /etc/vconsole.conf

# ============================================================
echo -e "${GREEN}[7/17] Zeitzone setzen ...${NC}"
ln -sf /usr/share/zoneinfo/Europe/Berlin /etc/localtime

# ============================================================
echo -e "${GREEN}[8/17] Sudo und Nano installieren ...${NC}"
pacman -S --noconfirm sudo nano

# ============================================================
echo -e "${GREEN}[9/17] Benutzer alarm zur sudo-Gruppe hinzufügen ...${NC}"
usermod -aG wheel alarm
echo '%wheel ALL=(ALL:ALL) ALL' > /etc/sudoers.d/wheel
chmod 440 /etc/sudoers.d/wheel

# ============================================================
echo -e "${GREEN}[10/17] Systemupdate ...${NC}"
pacman -Syu --noconfirm

# ============================================================
echo -e "${GREEN}[11/17] Mesa-Grafiktreiber (inkl. lib32 & fbdev) installieren ...${NC}"
pacman -S --noconfirm mesa lib32-mesa xf86-video-fbdev

# ============================================================
echo -e "${GREEN}[12/17] KDE Plasma 6 installieren ...${NC}"
echo -e "${YELLOW}  Wähle bei Nachfragen: 1 (ffmpeg), 2 (pipewire-jack), 5 (ttf-dejavu)${NC}"
pacman -S --noconfirm plasma-meta

# ============================================================
echo -e "${GREEN}[13/17] Dolphin und Konsole installieren ...${NC}"
pacman -S --noconfirm dolphin konsole

# ============================================================
echo -e "${GREEN}[14/17] SDDM installieren und aktivieren ...${NC}"
pacman -S --noconfirm sddm
systemctl enable sddm

# ============================================================
# Der laut Anweisung verlangte automatische Sprung ans Ende des Skripts
# ============================================================
echo -e "${GREEN}[15/17] SDDM Tastatur konfigurieren ...${NC}"
localectl set-keymap de-latin1
mkdir -p /etc/sddm.conf.d
cat > /etc/sddm.conf.d/keyboard.conf << EOF
[General]
InputMethod=

[Theme]
Current=breeze
EOF

# ============================================================
echo -e "${GREEN}[16/17] Von systemd-networkd auf NetworkManager umschalten ...${NC}"
systemctl disable systemd-networkd
systemctl enable NetworkManager

# NetworkManager Connectivity-Check konfigurieren
mkdir -p /etc/NetworkManager/conf.d
cat > /etc/NetworkManager/conf.d/20-connectivity.conf << EOF
[connectivity]
uri=http://nmcheck.gnome.org/check_network_status.txt
interval=300
EOF

# ============================================================
echo -e "${GREEN}[17/17] Passwörter setzen ...${NC}"
echo ""
echo -e "${YELLOW}Bitte jetzt das root-Passwort setzen:${NC}"
passwd root
echo ""
echo -e "${YELLOW}Bitte jetzt das Passwort für alarm setzen:${NC}"
passwd alarm

# ============================================================
echo ""
echo -e "${GREEN}═══ Fertig! ═══${NC}"
echo -e "${YELLOW}Neustart in 5 Sekunden ... (SSH-Verbindung wird getrennt)${NC}"
echo ""
rm -- "$0"
sleep 5
reboot
