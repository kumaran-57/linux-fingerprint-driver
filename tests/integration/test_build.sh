#!/usr/bin/env bash
set -euo pipefail

echo "=== Integration Test: Build Patched libfprint ==="

BUILD_DIR="/tmp/libfprint-build"
SRC_DIR="/tmp/libfprint-elanpress"

if [ ! -d "$BUILD_DIR" ]; then
    echo "[*] Setting up build directory..."
    meson setup "$BUILD_DIR" "$SRC_DIR" -Ddoc=false -Dinstalled-tests=false
fi

echo "[*] Compiling with ninja..."
ninja -C "$BUILD_DIR"

echo "[*] Verifying driver assignment for 04f3:0903..."
"$BUILD_DIR/libfprint/fprint-list-supported-devices" | grep "04f3:0903"

echo "[*] Running udev hwdb test..."
meson test -C "$BUILD_DIR" libfprint:udev-hwdb

echo "=== Integration Test Passed Successfully ==="
