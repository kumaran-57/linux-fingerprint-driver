#!/usr/bin/env bash
set -euo pipefail

echo "=========================================================="
echo " ASUS VivoBook 16X Fingerprint Support Check"
echo "=========================================================="

# 1. Check USB Hardware
echo -n "[*] Checking for ELAN Fingerprint Sensor (04f3:0903)... "
if lsusb -d 04f3:0903 >/dev/null 2>&1; then
    echo "DETECTED"
    lsusb -d 04f3:0903
else
    echo "NOT FOUND"
    exit 1
fi

# 2. Check installed packages
echo -n "[*] Checking libfprint package... "
LIBFPRINT_VER=$(dpkg-query -W -f='${Version}' libfprint-2-2 2>/dev/null || echo "not installed")
echo "$LIBFPRINT_VER"

echo -n "[*] Checking fprintd package... "
FPRINTD_VER=$(dpkg-query -W -f='${Version}' fprintd 2>/dev/null || echo "not installed")
echo "$FPRINTD_VER"

# 3. Check D-Bus Daemon Status
echo -n "[*] Querying fprintd D-Bus interface... "
if busctl introspect net.reactivated.Fprint /net/reactivated/Fprint/Device/0 >/dev/null 2>&1; then
    DEV_NAME=$(busctl get-property net.reactivated.Fprint /net/reactivated/Fprint/Device/0 net.reactivated.Fprint.Device name | tr -d '"s')
    SCAN_TYPE=$(busctl get-property net.reactivated.Fprint /net/reactivated/Fprint/Device/0 net.reactivated.Fprint.Device scan-type | tr -d '"s')
    STAGES=$(busctl get-property net.reactivated.Fprint /net/reactivated/Fprint/Device/0 net.reactivated.Fprint.Device num-enroll-stages | awk '{print $2}')
    echo "ONLINE"
    echo "    Device Name: $DEV_NAME"
    echo "    Current Scan Type: $SCAN_TYPE"
    echo "    Enrollment Stages: $STAGES"
    
    if [ "$SCAN_TYPE" = "swipe" ]; then
        echo "    [!] WARNING: Active driver reports 'swipe' for a physical touch sensor."
        echo "    [!] Upstream legacy driver 'elan' is active. Touch-press driver needed."
    elif [ "$SCAN_TYPE" = "press" ]; then
        echo "    [+] SUCCESS: Touch-press driver is active."
    fi
else
    echo "OFFLINE / NO DEVICE CLAIMED"
fi

# 4. Check PAM Configuration
echo -n "[*] Checking PAM configuration... "
if grep -q "pam_fprintd.so" /etc/pam.d/common-auth; then
    echo "CONFIGURED (pam_fprintd enabled with fallback)"
else
    echo "NOT ENABLED in common-auth"
fi

echo "=========================================================="
