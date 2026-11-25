# Linux Touch Fingerprint Driver — ELAN 04f3:0903 (ASUS VivoBook 16X)

An open-source touch/press fingerprint driver for **ELAN Microelectronics** capacitive sensors (`04f3:0903`) found on the **ASUS VivoBook 16X** and compatible laptops running Linux (Debian, Kali, Ubuntu, Fedora, Arch).

This project ports `04f3:0903` from legacy swipe-stitching to the modern `elanpress` touch architecture in `libfprint`, bringing Windows Hello-grade fingerprint authentication to Linux.

---

## 🎯 Target Hardware & System Architecture

- **Target Laptop:** ASUS VivoBook 16X (`M1603QA_M1603QA` / AMD Ryzen 5000 series)
- **Sensor Vendor:** ELAN Microelectronics Corp. (`ELAN:Fingerprint`)
- **USB Hardware ID:** `04f3:0903` (bcdDevice: `1.70`, USB 2.0 Full Speed 12 Mbps)
- **Sensor Type:** Capacitive Touch Area Sensor (integrated into top-right touchpad corner)
- **Host Matching:** SIFT (Scale-Invariant Feature Transform) keypoint extraction + Lowe's ratio test + rigid geometric alignment

---

## 🔍 The Problem & Root Cause

1. **The Stock Upstream Bug:**
   In stock `libfprint` (from v0.8 through v1.94.10), `04f3:0903` is routed to the legacy `elan.c` driver, which assumes all devices are swipe strips (`FP_SCAN_TYPE_SWIPE`). When a user presses or taps their finger, `elan.c` expects sliding movement to stitch frames; receiving only stationary frames, it errors out with `FP_DEVICE_RETRY_TOO_SHORT` ("swipe too short"), making touch enrollment or verification fail.

2. **USB Bus Saturation & Spurious Timeouts:**
   Early `elanpress` ports configured idle polling at 5ms intervals. Because each frame is ~18 KB (84x108 pixels @ 16-bit depth), polling at 5ms attempts to push ~3.7 MB/s across a USB 2.0 Full Speed bus capped at 1.5 MB/s (12 Mbps). This caused severe buffer starvation, frame drops, and premature timeouts aborting verification without a touch.

3. **Package Persistence on Debian/Kali:**
   Manually copying library files into `/usr/lib/` or creating backups like `.stock-backup` in the library search path caused `ldconfig` to switch dynamic linker symlinks back to stock swipe drivers on system updates, and `apt upgrade` wiped untracked files.

---

## ⚡ Technical Solutions in This Release

- **Native Touch Semantics:** Ports `04f3:0903` to `elanpress` (`FP_SCAN_TYPE_PRESS`) and removes it from `elan.h`.
- **Bus-Paced Polling (40ms / 25 fps):** Prevents USB bus saturation on 12 Mbps links while maintaining instant touch response (<40ms latency).
- **Graceful Timeout Handling:** Increases transfer timeout from 2000ms to 5000ms, and retries idle polling (both frame reads and background refreshes) during transient delays instead of crashing verification.
- **Tuned PAM Integration:** Enables 3 fingerprint retries (`max-tries=3`), removes idle GDM login-screen timeouts (`timeout=-1` in `gdm-fingerprint`), and bypasses `pam_fprintd` inside `gdm-password` so password logins are instantaneous.
- **Production Debian Package (`.deb`):** Packaged with epoch `2:1.94.10-2+elanpress` so `apt upgrade` will never overwrite the driver, with automated cleanups in `preinst`/`postinst` to prevent `ldconfig` poisoning.

---

## 📦 Quick Installation (.deb Package)

Ready-to-install Debian package is available in the [`releases/`](releases/) directory.

### Install via APT
```bash
sudo apt install ./releases/libfprint-2-2_2.1.94.10-2+elanpress_amd64.deb
```
Or run the automated installer:
```bash
sudo ./scripts/install.sh
```

### Enroll Your Fingerprint
```bash
fprintd-enroll
# Touch the sensor repeatedly (12 touches at slightly varied angles) until complete.
```

### Verify Verification
```bash
fprintd-verify
```

---

## 🔑 Important: GNOME Keyring & Fingerprint Login

### The "Password Mismatch" or Prompt on Opening Apps
When you log in to your desktop using a fingerprint, you may see a dialog when opening apps like Google Chrome, VS Code, or IDEs:
> *"The password you use to log in to your computer no longer matches that of your login keyring."*

#### Why does this happen?
Your login keyring (`login.keyring`) is encrypted on disk with your user password. When you log in with a **password**, PAM passes your plaintext password to `pam_gnome_keyring.so`, which decrypts your keyring automatically. When you log in with a **fingerprint**, PAM verifies your biometric identity, but biometrics cannot decrypt an AES-encrypted password database because Linux PAM does not store your plaintext password in memory.

#### Solutions:
- **Option A (Recommended for 100% Touch Automation):**
  Set your keyring password to blank (empty):
  1. Open the **Passwords and Keys** application (`seahorse`).
  2. Right-click **Login** (or **Default**) under *Keyrings* and select **Change Password**.
  3. Enter your current password.
  4. Leave the **New Password** field completely blank and click **Continue** (select *Use Unsafe Storage*).
  *Result: The keyring unlocks automatically on boot without prompting, even when logging in via fingerprint.*

- **Option B (Maximum Security):**
  Keep a password on your keyring. Enter your password at the initial cold boot / login screen (which unlocks the keyring for the day), and use the fingerprint sensor for:
  - Screen wake / lockscreen unlock (`Win + L`)
  - Terminal `sudo`
  - Polkit GUI administrative prompts

---

## 🛠️ Building from Source

To compile and package the driver locally:

```bash
# 1. Install build dependencies
sudo apt update
sudo apt install -y build-essential meson ninja-build pkg-config \
    libusb-1.0-0-dev libglib2.0-dev libgudev-1.0-dev libgusb-dev \
    libpixman-1-dev libssl-dev libcairo2-dev gobject-introspection \
    libgirepository1.0-dev dpkg-dev

# 2. Build the Debian package
./packaging/build-deb.sh
```

---

## 📂 Repository Layout

```
linux-fingerprint-driver/
├── README.md                                 # Project documentation
├── LICENSE                                   # GNU LGPL v2.1
├── releases/
│   └── libfprint-2-2_2.1.94.10-2+elanpress_amd64.deb  # Release binary package
├── docs/
│   ├── HARDWARE_INVENTORY.md                 # Sensor & host diagnostic specifications
│   ├── SUPPORT_RESEARCH.md                   # Kernel & libfprint driver analysis
│   ├── REVERSE_ENGINEERING.md                # Windows WHQL driver protocol analysis
│   ├── ARCHITECTURE.md                       # Driver & biometric stack architecture
│   ├── SECURITY.md                           # PAM configuration & biometric security
│   ├── INSTALLATION.md                       # Comprehensive installation guide
│   ├── TEST_REPORT.md                        # Verification & test results
│   ├── TROUBLESHOOTING.md                    # Common issues and solutions
│   └── ROADMAP.md                            # Multi-vendor roadmap
├── src/
│   └── drivers/
│       ├── elanpress.c                       # ELAN touch driver implementation
│       ├── elanpress.h                       # Device ID table & protocol opcodes
│       ├── elanpress-match.c                 # Keypoint pairing & geometric fitting
│       ├── elanpress-match.h                 # Matching thresholds & quality checks
│       ├── elanpress-sift.c                  # In-tree SIFT feature extractor
│       └── elanpress-sift.h                  # SIFT structures & interfaces
├── tests/
│   ├── unit/
│   │   └── test_protocol.c                   # Protocol framing & opcode verification
│   ├── integration/
│   │   └── test_build.sh                     # Automated build verification
│   └── mocks/
│       └── mock_sensor.c                     # Simulated USB sensor lifecycle test
├── scripts/
│   ├── install.sh                            # Production deb package installer
│   ├── rollback.sh                           # Clean rollback to stock distribution
│   ├── check_support.sh                      # Live support & scan-type check
│   └── collect_hardware_info.sh              # Diagnostic hardware discovery script
└── packaging/
    ├── build-deb.sh                          # Automated Debian package builder
    └── 0001-elanpress-support-04f3-0903.patch # Patch against upstream libfprint
```

---

## 🔄 Rollback to Stock Driver

If you ever wish to return to the distribution's default package:
```bash
sudo ./scripts/rollback.sh
```

---

## 🙌 Acknowledgments & License

- Built upon upstream [`libfprint`](https://gitlab.freedesktop.org/libfprint/libfprint) and the [`elanpress`](https://github.com/filip-rs/libfprint/tree/elanpress) touch-driver architecture (Copyright © 2026 Filip Spanne).
- Licensed under the **GNU Lesser General Public License v2.1 or later (LGPL-2.1+)**, matching upstream `libfprint`. See [`LICENSE`](LICENSE) for details.
