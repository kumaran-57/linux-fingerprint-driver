#!/usr/bin/env bash
set -euo pipefail

OUTPUT_FILE="${1:-/tmp/fingerprint_hardware_info.txt}"
mkdir -p "$(dirname "$OUTPUT_FILE")"

echo "=== System & Hardware Discovery ===" | tee "$OUTPUT_FILE"
echo "Date: $(date -Iseconds)" | tee -a "$OUTPUT_FILE"

echo -e "\n--- OS & Kernel ---" | tee -a "$OUTPUT_FILE"
cat /etc/os-release | tee -a "$OUTPUT_FILE"
uname -a | tee -a "$OUTPUT_FILE"

echo -e "\n--- DMI Information ---" | tee -a "$OUTPUT_FILE"
for f in sys_vendor product_name product_version product_family board_name bios_version bios_date; do
    if [ -f "/sys/class/dmi/id/$f" ]; then
        echo "$f: $(cat /sys/class/dmi/id/$f 2>/dev/null)" | tee -a "$OUTPUT_FILE"
    fi
done

echo -e "\n--- Desktop Session ---" | tee -a "$OUTPUT_FILE"
echo "XDG_CURRENT_DESKTOP=${XDG_CURRENT_DESKTOP:-unknown}" | tee -a "$OUTPUT_FILE"
echo "DESKTOP_SESSION=${DESKTOP_SESSION:-unknown}" | tee -a "$OUTPUT_FILE"

echo -e "\n--- USB Fingerprint Device ---" | tee -a "$OUTPUT_FILE"
lsusb -d 04f3: | tee -a "$OUTPUT_FILE"
lsusb -v -d 04f3:0903 2>/dev/null | tee -a "$OUTPUT_FILE" || true

echo -e "\n--- Udev Device Properties ---" | tee -a "$OUTPUT_FILE"
DEV_PATH=$(udevadm info -q path -n /dev/bus/usb/001/002 2>/dev/null || true)
if [ -n "$DEV_PATH" ]; then
    udevadm info -p "$DEV_PATH" | tee -a "$OUTPUT_FILE"
fi

echo -e "\n--- Installed Biometric Packages ---" | tee -a "$OUTPUT_FILE"
dpkg-query -W -f='${Package} ${Version}\n' libfprint-2-2 fprintd 2>/dev/null | tee -a "$OUTPUT_FILE" || true

echo -e "\n--- Fprint D-Bus State ---" | tee -a "$OUTPUT_FILE"
busctl introspect net.reactivated.Fprint /net/reactivated/Fprint/Device/0 2>&1 | tee -a "$OUTPUT_FILE" || true

echo -e "\nReport written to $OUTPUT_FILE"
