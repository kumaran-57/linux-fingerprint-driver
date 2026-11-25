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
PKG_VERSION="2:1.94.10-2+elanpress"
DEB_FILENAME="libfprint-2-2_2.1.94.10-2+elanpress_amd64.deb"

echo "=== [1/6] Checking build dependencies ==="
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
if [ -d "/tmp/libfprint-elanpress/.git" ]; then
    cp -a /tmp/libfprint-elanpress "${SRC_DIR}"
    git -C "${SRC_DIR}" checkout -- .
else
    git clone --depth 1 -b "${UPSTREAM_BRANCH}" "${UPSTREAM_REPO}" "${SRC_DIR}"
fi

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
    -Dudev_hwdb=enabled

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
cat << EOF > "${PKG_DIR}/DEBIAN/control"
Package: libfprint-2-2
Version: ${PKG_VERSION}
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
 Includes 40ms USB Full Speed bus pacing, resilient idle timeout handling
 during indefinite login screen waits, 3-retry PAM configuration, and fast
 GDM password login bypass.
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

# Back up and tune PAM settings for 3 retries, fast password login, and no login-screen idle timeout
PAM_BACKUP_DIR="/var/backups/libfprint/pam"
mkdir -p "${PAM_BACKUP_DIR}"

if [ -f /etc/pam.d/common-auth ]; then
    [ -f "${PAM_BACKUP_DIR}/common-auth.orig" ] || cp -a /etc/pam.d/common-auth "${PAM_BACKUP_DIR}/common-auth.orig"
    if grep -q 'pam_fprintd\.so' /etc/pam.d/common-auth; then
        sed -i -E 's/pam_fprintd\.so([[:space:]].*)?$/pam_fprintd.so max-tries=3 timeout=20/' /etc/pam.d/common-auth
        if ! grep -q 'pam_succeed_if\.so quiet service in gdm-password:kde' /etc/pam.d/common-auth; then
            sed -i '/pam_fprintd\.so/i auth\t[success=1 default=ignore]\tpam_succeed_if.so quiet service in gdm-password:kde' /etc/pam.d/common-auth
        fi
    fi
fi

if [ -f /usr/share/pam-configs/fprintd ]; then
    [ -f "${PAM_BACKUP_DIR}/pam-configs-fprintd.orig" ] || cp -a /usr/share/pam-configs/fprintd "${PAM_BACKUP_DIR}/pam-configs-fprintd.orig"
    sed -i -E 's/pam_fprintd\.so([[:space:]].*)?$/pam_fprintd.so max-tries=3 timeout=20/' /usr/share/pam-configs/fprintd
fi

for gdm_pam in /etc/pam.d/gdm-fingerprint /etc/pam.d/kde-fingerprint; do
    if [ -f "${gdm_pam}" ]; then
        base_name="$(basename "${gdm_pam}")"
        [ -f "${PAM_BACKUP_DIR}/${base_name}.orig" ] || cp -a "${gdm_pam}" "${PAM_BACKUP_DIR}/${base_name}.orig"
        sed -i -E '/^auth[[:space:]]/ s/pam_fprintd\.so([[:space:]].*)?$/pam_fprintd.so max-tries=3 timeout=-1/' "${gdm_pam}"
    fi
done

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

if [ "$1" = "remove" ] || [ "$1" = "purge" ]; then
    PAM_BACKUP_DIR="/var/backups/libfprint/pam"
    if [ -f "${PAM_BACKUP_DIR}/common-auth.orig" ]; then
        mv -f "${PAM_BACKUP_DIR}/common-auth.orig" /etc/pam.d/common-auth
    fi
    if [ -f "${PAM_BACKUP_DIR}/pam-configs-fprintd.orig" ] && [ -f /usr/share/pam-configs/fprintd ]; then
        mv -f "${PAM_BACKUP_DIR}/pam-configs-fprintd.orig" /usr/share/pam-configs/fprintd
    fi
    for base_name in gdm-fingerprint kde-fingerprint; do
        if [ -f "${PAM_BACKUP_DIR}/${base_name}.orig" ] && [ -f "/etc/pam.d/${base_name}" ]; then
            mv -f "${PAM_BACKUP_DIR}/${base_name}.orig" "/etc/pam.d/${base_name}"
        fi
    done
fi

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
rm -f "${RELEASE_DIR}"/libfprint-2-2_*.deb
OUTPUT_DEB="${RELEASE_DIR}/${DEB_FILENAME}"
dpkg-deb --build --root-owner-group "${PKG_DIR}" "${OUTPUT_DEB}"

echo "SUCCESS! Created package:"
ls -lh "${OUTPUT_DEB}"
dpkg-deb -I "${OUTPUT_DEB}"
