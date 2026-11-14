#!/usr/bin/env bash
# ==============================================================================
# rollback.sh - Revert to official stock distribution packages
# ==============================================================================

set -euo pipefail

if [ "$EUID" -ne 0 ]; then
    echo "[!] Please run with sudo: sudo ${0}"
    exit 1
fi

echo "=========================================================="
echo " Fingerprint Driver Rollback Procedure"
echo "=========================================================="

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

echo "[+] Rollback complete. Distro stock libfprint restored."
echo "=========================================================="
