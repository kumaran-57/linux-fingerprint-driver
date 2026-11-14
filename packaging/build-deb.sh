#!/usr/bin/env bash
# ==============================================================================
# build-deb.sh - Automated Debian Package Builder for Patched libfprint
# Supports: ASUS VivoBook 16X (ELAN 04f3:0903) & compatible touch sensors
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
BUILD_DIR="/tmp/libfprint-deb-build"
PKG_DIR="/tmp/libfprint-deb-pkg"
RELEASE_DIR="${PROJECT_ROOT}/releases"
PATCH_FILE="${PROJECT_ROOT}/packaging/0001-elanpress-support-04f3-0903.patch"
UPSTREAM_REPO="https://github.com/filip-rs/libfprint.git"
UPSTREAM_BRANCH="elanpress"
PKG_VERSION="2:1.94.10-1+elanpress"

echo "=== [1/6] Installing build dependencies (if needed) ==="
if ! command -v meson &>/dev/null || ! command -v ninja &>/dev/null || ! command -v dpkg-deb &>/dev/null; then
    echo "Missing build tools. Installing via apt..."
    sudo apt update
    sudo apt install -y build-essential meson ninja-build pkg-config \
        libusb-1.0-0-dev libglib2.0-dev libgudev-1.0-dev libgusb-dev \
        libpixman-1-dev libssl-dev libcairo2-dev gobject-introspection \
        libgirepository1.0-dev dpkg-dev
fi

echo "=== [2/6] Preparing source tree ==="
SRC_DIR="/tmp/libfprint-elanpress-src"
rm -rf "${SRC_DIR}" "${BUILD_DIR}" "${PKG_DIR}"
git clone --depth 1 -b "${UPSTREAM_BRANCH}" "${UPSTREAM_REPO}" "${SRC_DIR}"

echo "=== [3/6] Applying driver patch ==="
cd "${SRC_DIR}"
patch -p1 < "${PATCH_FILE}"

echo "=== [4/6] Compiling libfprint with Meson & Ninja ==="
meson setup "${BUILD_DIR}" "${SRC_DIR}" \
    --prefix=/usr \
    --sysconfdir=/etc \
    --libdir=/usr/lib/x86_64-linux-gnu \
    -Ddoc=false \
    -Dinstalled-tests=false \
    -Dudev_hw_db=enabled

ninja -C "${BUILD_DIR}"
ninja -C "${BUILD_DIR}" sync-udev-hwdb

echo "=== [5/6] Assembling Debian package layout ==="
mkdir -p "${PKG_DIR}/DEBIAN"
mkdir -p "${PKG_DIR}/usr/lib/x86_64-linux-gnu"
mkdir -p "${PKG_DIR}/usr/lib/udev/hwdb.d"
mkdir -p "${PKG_DIR}/usr/lib/udev/rules.d"
mkdir -p "${PKG_DIR}/usr/share/metainfo"

cp -a "${BUILD_DIR}/libfprint/libfprint-2.so.2.0.0" "${PKG_DIR}/usr/lib/x86_64-linux-gnu/"
ln -sf libfprint-2.so.2.0.0 "${PKG_DIR}/usr/lib/x86_64-linux-gnu/libfprint-2.so.2"
strip --strip-unneeded "${PKG_DIR}/usr/lib/x86_64-linux-gnu/libfprint-2.so.2.0.0"

cp -a "${BUILD_DIR}/libfprint/autosuspend.hwdb" "${PKG_DIR}/usr/lib/udev/hwdb.d/60-autosuspend-libfprint-2.hwdb"
cp -a "${BUILD_DIR}/libfprint/70-libfprint-2.rules" "${PKG_DIR}/usr/lib/udev/rules.d/"
cp -a "${BUILD_DIR}/libfprint/org.freedesktop.libfprint.metainfo.xml" "${PKG_DIR}/usr/share/metainfo/"

# Write DEBIAN/control
cat << 'EOF' > "${PKG_DIR}/DEBIAN/control"
Package: libfprint-2-2
Version: 2:1.94.10-1+elanpress
Architecture: amd64
Maintainer: Open Source Linux Fingerprint Community <linux-fingerprint@github.com>
Installed-Size: 850
Depends: libc6 (>= 2.38), libglib2.0-0t64 (>= 2.68.0), libgudev-1.0-0 (>= 146), libgusb2a (>= 0.3.3), libpixman-1-0 (>= 0.30.0), libssl3t64 (>= 3.0.0)
Section: libs
Priority: optional
Homepage: https://github.com/filip-rs/libfprint
Description: Async fingerprint library with ELAN touch press driver (04f3:0903)
 Patched libfprint-2 shared library providing native touch/press support for
 ELAN Microelectronics 04f3:0903 (ASUS VivoBook 16X M1603QA series) and
 related capacitive touch sensors (04f3:0c6e, 04f3:0c4f, 04f3:0c63).
 .
 Replaces broken swipe stitching with SIFT keypoint matching, Lowe's ratio test,
 multi-angle enrollment, and tuned 40ms bus polling to prevent USB Full Speed
 saturation and spurious timeouts.
EOF

# Write DEBIAN/preinst
cat << 'EOF' > "${PKG_DIR}/DEBIAN/preinst"
#!/bin/sh
set -e
if [ -f "/usr/lib/x86_64-linux-gnu/libfprint-2.so.2.0.0.stock-backup" ]; then
    mkdir -p /var/backups/libfprint
    mv -f "/usr/lib/x86_64-linux-gnu/libfprint-2.so.2.0.0.stock-backup" "/var/backups/libfprint/"
fi
exit 0
EOF

# Write DEBIAN/postinst
cat << 'EOF' > "${PKG_DIR}/DEBIAN/postinst"
#!/bin/sh
set -e
if [ -f "/usr/lib/x86_64-linux-gnu/libfprint-2.so.2.0.0.stock-backup" ]; then
    mkdir -p /var/backups/libfprint
    mv -f "/usr/lib/x86_64-linux-gnu/libfprint-2.so.2.0.0.stock-backup" "/var/backups/libfprint/"
fi
ln -sf libfprint-2.so.2.0.0 /usr/lib/x86_64-linux-gnu/libfprint-2.so.2
if command -v ldconfig >/dev/null 2>&1; then
    ldconfig
fi
if command -v systemd-hwdb >/dev/null 2>&1; then
    systemd-hwdb update || true
elif command -v udevadm >/dev/null 2>&1; then
    udevadm hwdb --update || true
fi
if command -v udevadm >/dev/null 2>&1; then
    udevadm control --reload-rules || true
    udevadm trigger --action=add --attr-match=idVendor=04f3 --attr-match=idProduct=0903 || true
fi
if [ -d /run/systemd/system ] && command -v systemctl >/dev/null 2>&1; then
    systemctl restart fprintd.service 2>/dev/null || true
fi
exit 0
EOF

# Write DEBIAN/postrm
cat << 'EOF' > "${PKG_DIR}/DEBIAN/postrm"
#!/bin/sh
set -e
if command -v ldconfig >/dev/null 2>&1; then
    ldconfig
fi
if command -v systemd-hwdb >/dev/null 2>&1; then
    systemd-hwdb update || true
elif command -v udevadm >/dev/null 2>&1; then
    udevadm hwdb --update || true
fi
if command -v udevadm >/dev/null 2>&1; then
    udevadm control --reload-rules || true
fi
exit 0
EOF

chmod 0755 "${PKG_DIR}/DEBIAN" "${PKG_DIR}/DEBIAN/preinst" "${PKG_DIR}/DEBIAN/postinst" "${PKG_DIR}/DEBIAN/postrm"
chmod 0644 "${PKG_DIR}/DEBIAN/control"
chmod -R u=rwX,go=rX "${PKG_DIR}/usr"

echo "=== [6/6] Generating Debian package (.deb) ==="
mkdir -p "${RELEASE_DIR}"
OUTPUT_DEB="${RELEASE_DIR}/libfprint-2-2_2.1.94.10-1+elanpress_amd64.deb"
dpkg-deb --build --root-owner-group "${PKG_DIR}" "${OUTPUT_DEB}"

echo "SUCCESS! Created package:"
ls -lh "${OUTPUT_DEB}"
dpkg-deb -I "${OUTPUT_DEB}"
