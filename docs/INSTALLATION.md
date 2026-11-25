# Installation & Build Guide

This guide details how to install the patched `libfprint` package containing the `elanpress` touch driver for ASUS VivoBook 16X (`04f3:0903`) and compatible laptops.

---

## 1. Quick Installation via Pre-Built Debian Package (.deb)

The easiest, cleanest, and most reliable method is using the pre-built `.deb` package in the `releases/` directory.

### Method A: Single APT Command
```bash
sudo apt install ./linux-fingerprint-driver/releases/libfprint-2-2_2.1.94.10-2+elanpress_amd64.deb
```

### Method B: Automated Installer Script
```bash
sudo ./linux-fingerprint-driver/scripts/install.sh
```

### What the `.deb` package includes:
- **Package Epoch Management:** The package is versioned with epoch `2:1.94.10-2+elanpress`. Standard distribution upgrades (`sudo apt update && sudo apt upgrade`) will never overwrite it with the stock swipe driver because epoch `2:` takes precedence over Debian's `1:`.
- **Dynamic Linker Protection:** Automatically relocates any conflicting `.stock-backup` files from `/usr/lib/x86_64-linux-gnu/` and runs `ldconfig` atomically.
- **PAM Integration Fixes:** Sets `max-tries=3 timeout=20` for `sudo`/Polkit retries, sets `timeout=-1` on `gdm-fingerprint` so sitting idle on the login screen never triggers verification timeouts, and skips `pam_fprintd` in `gdm-password` so password logins are instant.
- **Hardware Database Sync:** Automatically updates `systemd-hwdb` and triggers udev rules for `04f3:0903`.

---

## 2. Enrollment & Testing

Once installed:
```bash
# 1. Verify that the sensor is now recognized as 'press':
busctl get-property net.reactivated.Fprint /net/reactivated/Fprint/Device/0 net.reactivated.Fprint.Device scan-type
# Expected output: s "press"

# 2. Enroll your finger (press and lift 12 times at varying angles):
fprintd-enroll

# 3. Test verification:
fprintd-verify
```

---

## 3. Building the Debian Package from Source

If you want to compile from source or modify the driver:

### Prerequisites:
```bash
sudo apt update
sudo apt install -y build-essential meson ninja-build pkg-config \
    libusb-1.0-0-dev libglib2.0-dev libgudev-1.0-dev libgusb-dev \
    libpixman-1-dev libssl-dev libcairo2-dev gobject-introspection \
    libgirepository1.0-dev dpkg-dev fprintd
```

### Compile & Build Package:
```bash
./linux-fingerprint-driver/packaging/build-deb.sh
```
This script clones upstream `libfprint` (branch `elanpress`), applies our `0001-elanpress-support-04f3-0903.patch`, compiles with Meson/Ninja, strips binaries, and generates `releases/libfprint-2-2_2.1.94.10-2+elanpress_amd64.deb`.

---

## 4. Rollback to Distribution Default

To restore the official distribution package:
```bash
sudo ./linux-fingerprint-driver/scripts/rollback.sh
```
