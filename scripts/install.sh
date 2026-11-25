#!/usr/bin/env bash
# ==============================================================================
# install.sh - Clean production installer for ASUS VivoBook 16X fingerprint driver
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
DEB_PATH="${REPO_ROOT}/releases/libfprint-2-2_2.1.94.10-2+elanpress_amd64.deb"

if [ "$EUID" -ne 0 ]; then
    echo "[!] Please run with sudo: sudo ${0}"
    exit 1
fi

echo "=========================================================="
echo " Installing Patched Touch Fingerprint Driver (elanpress)"
echo " Device: ELAN 04f3:0903 (ASUS VivoBook 16X M1603QA)"
echo "=========================================================="

# 1. Check if deb package exists, build if not found
if [ ! -f "${DEB_PATH}" ]; then
    echo "[*] Release package not found. Building from source..."
    "${REPO_ROOT}/packaging/build-deb.sh"
fi

# 2. Install Debian package cleanly (postinst handles ldconfig, udev, and PAM tuning)
echo "[*] Installing Debian package ${DEB_PATH}..."
apt-get install -y --reinstall "${DEB_PATH}"

# 3. Verification
sleep 1
echo ""
echo "=== Verification ==="
if command -v busctl >/dev/null 2>&1 && busctl introspect net.reactivated.Fprint /net/reactivated/Fprint/Device/0 >/dev/null 2>&1; then
    NAME=$(busctl get-property net.reactivated.Fprint /net/reactivated/Fprint/Device/0 net.reactivated.Fprint.Device name 2>/dev/null | tr -d '"s' || echo "Unknown")
    SCAN_TYPE=$(busctl get-property net.reactivated.Fprint /net/reactivated/Fprint/Device/0 net.reactivated.Fprint.Device scan-type 2>/dev/null | tr -d '"s' || echo "Unknown")
    echo "  Device Name: ${NAME}"
    echo "  Scan Type:   ${SCAN_TYPE}"
    if [ "${SCAN_TYPE}" = "press" ]; then
        echo -e "\n[+] SUCCESS: Device is correctly operating in 'press' mode."
        echo "    You can enroll your finger using: fprintd-enroll \"${SUDO_USER:-$USER}\""
    fi
else
    echo "[*] Driver package installed successfully."
    echo "    To enroll a fingerprint: fprintd-enroll"
fi
echo "=========================================================="
