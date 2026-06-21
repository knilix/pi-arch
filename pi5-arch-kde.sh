#!/usr/bin/env bash
# Maintainer: @knilix
# ============================================================
# Script 2: alarm-rpi5-setup.sh
# Läuft auf dem Raspberry Pi 5 (als root via SSH).
# Richtet Arch Linux ARM mit KDE Plasma 6 ein.
# V.0.5
# ============================================================

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
echo -e "${GREEN}[3/17] Systemupdate ...${NC}"
pacman -Syu --noconfirm

# ============================================================
echo -e "${GREEN}[4/17] Pi 5 Kernel installieren und U-Boot entfernen ...${NC}"
# linux-aarch64 und uboot-raspberrypi sind Pi-5-inkompatibel → erst entfernen
# linux-rpi ebenfalls entfernen falls vorhanden (kein 16k pagesize)
# Dann linux-rpi-16k installieren (bcm2712, nur Pi 5)
pacman -Rns --noconfirm linux-aarch64 uboot-raspberrypi raspberrypi-bootloader || true
pacman -Rns --noconfirm linux-rpi 2>/dev/null || true
rm -rf /boot/*
pacman -S --noconfirm --needed --overwrite "*" linux-rpi-16k

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
pacman -S --noconfirm --needed sudo nano

# =================================================
