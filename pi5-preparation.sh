#!/usr/bin/env bash
# Maintainer: @knilix
# ============================================================
# Script 1: alarm-rpi5-prepare.sh
# Läuft auf dem Host-PC (Linux). Bereitet eine SD-Karte oder
# SSD für Arch Linux ARM auf dem Raspberry Pi 5 vor.
#
# Hintergrund: Der ALARM-Standard-Tarball enthält U-Boot und
# den linux-aarch64 Kernel. U-Boot unterstützt den Pi 5 NICHT
# → Boot stoppt beim Logo. Lösung: U-Boot entfernen und den
# linux-rpi Kernel (RPi Foundation Fork) nachladen. Die Version
# wird automatisch von archlinuxarm.org ermittelt.
# ============================================================

if [[ -z "${NOBUFFER:-}" ]]; then
    export NOBUFFER=1
    exec sudo NOBUFFER=1 "$0" "$@"
fi

set -euo pipefail

ALARM_URL="http://os.archlinuxarm.org/os/ArchLinuxARM-rpi-aarch64-latest.tar.gz"
ALARM_FILE="ArchLinuxARM-rpi-aarch64-latest.tar.gz"
LINUX_RPI_PKG_PAGE="https://archlinuxarm.org/packages/aarch64/linux-rpi"
MOUNT_ROOT="/mnt/arch"
MOUNT_BOOT="${MOUNT_ROOT}/boot"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

if [[ $EUID -ne 0 ]]; then
    echo -e "${RED} Dieses Script muss mit sudo oder als root ausgeführt werden.${NC}"
    exit 1
fi

echo ""
echo -e "${GREEN}=== Arch Linux ARM – Raspberry Pi 5 – Vorbereitung ===${NC}"
echo ""

# ── Aktuelle linux-rpi Version ermitteln ──────────────────────────────────────
echo -e "${YELLOW}Ermittle aktuelle linux-rpi Version von archlinuxarm.org ...${NC}"
LINUX_RPI_URL=$(curl -fsSL "${LINUX_RPI_PKG_PAGE}" \
    | grep -o 'http://mirror\.archlinuxarm\.org/aarch64/core/linux-rpi-[^"]*\.pkg\.tar\.xz' \
    | head -1)

if [[ -z "${LINUX_RPI_URL}" ]]; then
    echo -e "${RED}Fehler: Konnte linux-rpi Download-URL nicht ermitteln.${NC}"
    echo -e "${RED}Bitte manuell prüfen: ${LINUX_RPI_PKG_PAGE}${NC}"
    exit 1
fi

LINUX_RPI_VERSION=$(echo "${LINUX_RPI_URL}" | grep -o 'linux-rpi-[^-]*-[^-]*' | head -1)
LINUX_RPI_FILE="${LINUX_RPI_VERSION}-aarch64.pkg.tar.xz"
echo -e "  ${GREEN}Gefunden: ${LINUX_RPI_VERSION}${NC}"
echo ""

# ── Laufwerksauswahl ──────────────────────────────────────────────────────────
echo -e "${YELLOW}Verfügbare Laufwerke:${NC}"
echo ""
lsblk -d -o NAME,SIZE,MODEL,TRAN | grep -v loop || true
echo ""

echo -n "Ziel-Laufwerk (z.B. sdb, nvme0n1): "
read -r TARGET
TARGET="/dev/${TARGET}"

if [[ ! -b "${TARGET}" ]]; then
    echo -e "${RED} ${TARGET} existiert nicht. Abbruch.${NC}"
    exit 1
fi

echo ""
echo -e "${YELLOW}  ALLE DATEN AUF ${TARGET} WERDEN UNWIDERRUFLICH GELÖSCHT!${NC}"
echo -n "Fortfahren? (ja/Nein): "
read -r confirm
[[ "${confirm}" != "ja" ]] && { echo "Abgebrochen."; exit 0; }

if [[ "${TARGET}" == *"nvme"* ]]; then
    PART1="${TARGET}p1"; PART2="${TARGET}p2"
else
    PART1="${TARGET}1";  PART2="${TARGET}2"
fi

# ── Schritt 1: ALARM-Tarball ──────────────────────────────────────────────────
echo ""
echo -e "${GREEN}[1/10] ALARM-Image herunterladen ...${NC}"
if [[ -f "${ALARM_FILE}" ]]; then
    echo -n "  ${ALARM_FILE} existiert bereits. Neu herunterladen? (j/N): "
    read -r redl
    [[ "${redl}" == "j" ]] && { rm -f "${ALARM_FILE}"; wget -O "${ALARM_FILE}" "${ALARM_URL}"; }
else
    wget -O "${ALARM_FILE}" "${ALARM_URL}"
fi

# ── Schritt 2: linux-rpi Kernel ───────────────────────────────────────────────
echo ""
echo -e "${GREEN}[2/10] linux-rpi Kernel herunterladen (${LINUX_RPI_VERSION}) ...${NC}"
echo -e "  ${YELLOW}Ersetzt U-Boot + linux-aarch64 (Pi 5 inkompatibel)${NC}"
if [[ -f "${LINUX_RPI_FILE}" ]]; then
    echo -n "  ${LINUX_RPI_FILE} existiert bereits. Neu herunterladen? (j/N): "
    read -r redl2
    [[ "${redl2}" == "j" ]] && { rm -f "${LINUX_RPI_FILE}"; wget -O "${LINUX_RPI_FILE}" "${LINUX_RPI_URL}"; }
else
    wget -O "${LINUX_RPI_FILE}" "${LINUX_RPI_URL}"
fi

# ── Schritt 3: Partition bereinigen ───────────────────────────────────────────
echo ""
echo -e "${GREEN}[3/10] Partitionstabelle bereinigen ...${NC}"
dd if=/dev/zero of="${TARGET}" bs=1M count=50 status=progress

# ── Schritt 4: Partitionen anlegen ────────────────────────────────────────────
echo ""
echo -e "${GREEN}[4/10] Partitionen anlegen ...${NC}"
sfdisk "${TARGET}" <<EOF
label: dos
start=2048,   size=524288, type=c
start=526336, type=83
EOF
sleep 2
partprobe "${TARGET}" 2>/dev/null || true

# ── Schritt 5: Dateisysteme ───────────────────────────────────────────────────
echo ""
echo -e "${GREEN}[5/10] Dateisysteme erstellen ...${NC}"
mkfs.vfat -F 32 "${PART1}"
mkfs.ext4 -F "${PART2}"

# ── Schritt 6: Mounten ────────────────────────────────────────────────────────
echo ""
echo -e "${GREEN}[6/10] Partitionen mounten ...${NC}"
mkdir -p "${MOUNT_ROOT}"
mount "${PART2}" "${MOUNT_ROOT}"
mkdir -p "${MOUNT_BOOT}"
mount "${PART1}" "${MOUNT_BOOT}"

# ── Schritt 7: ALARM entpacken ────────────────────────────────────────────────
echo ""
echo -e "${GREEN}[7/10] Root-Dateisystem entpacken ...${NC}"
bsdtar -xpf "${ALARM_FILE}" -C "${MOUNT_ROOT}"
sync

# ── Schritt 8: U-Boot ersetzen durch linux-rpi ───────────────────────────────
echo ""
echo -e "${GREEN}[8/10] U-Boot entfernen und linux-rpi einspielen ...${NC}"
echo -e "  ${YELLOW}Entferne U-Boot (nicht Pi-5-kompatibel) ...${NC}"
rm -f "${MOUNT_BOOT}/kernel8.img"
rm -f "${MOUNT_BOOT}/u-boot.bin"

echo -e "  ${YELLOW}Entpacke linux-rpi Kernel ...${NC}"
TMPDIR_KERNEL=$(mktemp -d)
bsdtar -xf "${LINUX_RPI_FILE}" -C "${TMPDIR_KERNEL}"

cp -rf "${TMPDIR_KERNEL}/boot/." "${MOUNT_BOOT}/"
if [[ -d "${TMPDIR_KERNEL}/usr/lib/modules" ]]; then
    cp -rf "${TMPDIR_KERNEL}/usr/lib/modules" "${MOUNT_ROOT}/usr/lib/"
fi
rm -rf "${TMPDIR_KERNEL}"
sync

echo -e "  ${GREEN}Kernel-Images vorhanden:${NC}"
ls "${MOUNT_BOOT}"/kernel*.img 2>/dev/null \
    && true \
    || echo -e "  ${RED}Warnung: Kein kernel*.img gefunden – Paket prüfen!${NC}"

# ── Schritt 9: fstab / cmdline.txt / config.txt ───────────────────────────────
echo ""
echo -e "${GREEN}[9/10] UUIDs auslesen und fstab/cmdline/config schreiben ...${NC}"
UUID_BOOT=$(blkid -s UUID -o value "${PART1}")
UUID_ROOT=$(blkid -s UUID -o value "${PART2}")
echo "  UUID Boot: ${UUID_BOOT}"
echo "  UUID Root: ${UUID_ROOT}"

cat > "${MOUNT_ROOT}/etc/fstab" <<EOF
UUID=${UUID_ROOT}  /       ext4    defaults        0       1
UUID=${UUID_BOOT}  /boot   vfat    defaults        0       2
EOF

# Kein U-Boot mehr → Kernel startet direkt, rootfstype explizit angeben
echo "console=serial0,115200 console=tty1 root=UUID=${UUID_ROOT} rw rootwait rootfstype=ext4" \
    > "${MOUNT_BOOT}/cmdline.txt"

# config.txt: kein kernel= nötig – linux-rpi bringt eigene Bootconfig mit
cat >> "${MOUNT_BOOT}/config.txt" <<EOF

# Raspberry Pi 5 – Einstellungen
enable_uart=1
arm_64bit=1
EOF

echo -e "  ${GREEN}fstab, cmdline.txt und config.txt geschrieben${NC}"

# ── Schritt 10: Aushängen ─────────────────────────────────────────────────────
echo ""
echo -e "${GREEN}[10/10] Sauber aushängen ...${NC}"
sync
umount "${MOUNT_BOOT}"
umount "${MOUNT_ROOT}"

echo ""
echo -e "${GREEN}═══ Fertig! ═══${NC}"
echo -e "${YELLOW}SSD/SD in den Pi 5 stecken, LAN an, Strom an.${NC}"
echo -e "${YELLOW}Danach Script 2 per SSH ausführen.${NC}"
