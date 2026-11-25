#!/usr/bin/env bash
# ==============================================================================
# rollback.sh - Revert to official stock distribution packages & PAM defaults
# ==============================================================================

set -euo pipefail

if [ "$EUID" -ne 0 ]; then
    echo "[!] Please run with sudo: sudo ${0}"
    exit 1
fi

echo "=========================================================="
echo " Fingerprint Driver Rollback Procedure"
echo "=========================================================="

PAM_BACKUP_DIR="/var/backups/libfprint/pam"
if [ -f "${PAM_BACKUP_DIR}/common-auth.orig" ]; then
    echo "[*] Restoring /etc/pam.d/common-auth..."
    mv -f "${PAM_BACKUP_DIR}/common-auth.orig" /etc/pam.d/common-auth
fi
if [ -f "${PAM_BACKUP_DIR}/pam-configs-fprintd.orig" ] && [ -f /usr/share/pam-configs/fprintd ]; then
    echo "[*] Restoring /usr/share/pam-configs/fprintd..."
    mv -f "${PAM_BACKUP_DIR}/pam-configs-fprintd.orig" /usr/share/pam-configs/fprintd
fi
for base_name in gdm-fingerprint kde-fingerprint; do
    if [ -f "${PAM_BACKUP_DIR}/${base_name}.orig" ] && [ -f "/etc/pam.d/${base_name}" ]; then
        echo "[*] Restoring /etc/pam.d/${base_name}..."
        mv -f "${PAM_BACKUP_DIR}/${base_name}.orig" "/etc/pam.d/${base_name}"
    fi
done

echo "[*] Reinstalling official distribution package from repository..."
apt-get install -y --allow-downgrades libfprint-2-2=1:* fprintd || \
apt-get install -y --allow-downgrades libfprint-2-2 fprintd

if [ -f "/var/backups/libfprint/libfprint-2.so.2.0.0.stock-backup" ]; then
    echo "[*] Cleaning up backup directory..."
    rm -f "/var/backups/libfprint/libfprint-2.so.2.0.0.stock-backup"
fi

if command -v ldconfig >/dev/null 2>&1; then
    ldconfig
fi

if [ -d /run/systemd/system ]; then
    systemctl restart fprintd.service || true
fi

echo "[+] Rollback complete. Distro stock libfprint and PAM defaults restored."
echo "=========================================================="
