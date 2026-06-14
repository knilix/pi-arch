#!/usr/bin/env bash
# Maintainer: @knilix
# ============================================================
# Script 2: pi4-arch-kde.sh
# Läuft auf dem Raspberry Pi 4 (als root via SSH).
# Richtet am Arch Linux ARM KDE Plasma 6 ein.
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
echo -e "${GREEN}=== Arch Linux ARM – Raspberry Pi 4 – Einrichtung ===${NC}"
echo ""

# ============================================================
echo -e "${GREEN}[1/16] SSH-Dienst aktivieren ...${NC}"
systemctl enable sshd

# ============================================================
echo -e "${GREEN}[2/16] Pacman-Schlüssel initialisieren ...${NC}"
pacman-key --init
pacman-key --populate archlinuxarm

# ============================================================
echo -e "${GREEN}[3/16] Hostname setzen ...${NC}"
echo "arch-arm" > /etc/hostname

# ============================================================
echo -e "${GREEN}[4/16] Locale setzen ...${NC}"
sed -i 's/^#de_DE.UTF-8/de_DE.UTF-8/' /etc/locale.gen
locale-gen
echo "LANG=de_DE.UTF-8" > /etc/locale.conf
echo "KEYMAP=de-latin1" > /etc/vconsole.conf

# ============================================================
echo -e "${GREEN}[5/16] Zeitzone setzen ...${NC}"
ln -sf /usr/share/zoneinfo/Europe/Berlin /etc/localtime

# ============================================================
echo -e "${GREEN}[6/16] Sudo und Nano installieren ...${NC}"
pacman -S --noconfirm sudo nano

# ============================================================
echo -e "${GREEN}[7/16] Benutzer alarm zur sudo-Gruppe hinzufügen ...${NC}"
usermod -aG wheel alarm
echo '%wheel ALL=(ALL:ALL) ALL' > /etc/sudoers.d/wheel
chmod 440 /etc/sudoers.d/wheel

# ============================================================
echo -e "${GREEN}[8/16] Systemupdate ...${NC}"
pacman -Syu --noconfirm

# ============================================================
echo -e "${GREEN}[9/16] Mesa installieren ...${NC}"
pacman -S --noconfirm mesa

# ============================================================
echo -e "${GREEN}[10/16] KDE Plasma 6 installieren ...${NC}"
echo -e "${YELLOW}  Wähle bei Nachfragen: 1 (ffmpeg), 2 (pipewire-jack), 5 (ttf-dejavu)${NC}"
pacman -S --noconfirm plasma-meta

# ============================================================
echo -e "${GREEN}[11/16] Dolphin und Konsole installieren ...${NC}"
pacman -S --noconfirm dolphin konsole

# ============================================================
echo -e "${GREEN}[12/16] SDDM installieren und aktivieren ...${NC}"
pacman -S --noconfirm sddm
systemctl enable sddm

# ============================================================
echo -e "${GREEN}[13/16] SDDM Tastatur konfigurieren ...${NC}"
localectl set-keymap de-latin1
mkdir -p /etc/sddm.conf.d
cat > /etc/sddm.conf.d/keyboard.conf << EOF
[General]
InputMethod=

[Theme]
Current=breeze
EOF

# ============================================================
echo -e "${GREEN}[14/16] Von systemd-networkd auf NetworkManager umschalten ...${NC}"
systemctl disable systemd-networkd
systemctl enable NetworkManager

# ============================================================
echo -e "${GREEN}[15/16] Passwörter setzen ...${NC}"
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
sleep 5
reboot
