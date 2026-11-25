# ELAN Touch Fingerprint Driver for Linux (`04f3:0903`)

An open-source `libfprint` touch/press driver and Debian package for **ELAN Microelectronics** capacitive fingerprint sensors (`04f3:0903`), including the sensor built into the **ASUS VivoBook 16X** (`M1603QA`) and compatible laptops running Debian, Kali Linux, or Ubuntu.

---

## Overview

In upstream `libfprint`, USB ID `04f3:0903` is routed to the legacy `elan` driver, which hardcodes `FP_SCAN_TYPE_SWIPE` and expects sliding frames for movement stitching. Because `04f3:0903` is a stationary capacitive touch area sensor, tapping or resting a finger fails with `FP_DEVICE_RETRY_TOO_SHORT` ("swipe too short").

This project ports `04f3:0903` to the modern `elanpress` touch architecture and resolves downstream USB bandwidth, timeout, and PAM integration issues for reliable desktop, lockscreen, and `sudo` authentication.

### Key Capabilities

- **Native Press Semantics:** Replaces swipe stitching with `FP_SCAN_TYPE_PRESS`, 12-stage multi-angle enrollment, SIFT keypoint extraction, and geometric alignment matching.
- **USB Full Speed Pacing:** Tunes idle and capture polling to 40 ms (~25 fps) to prevent USB 2.0 Full Speed (12 Mbps) bus saturation and frame drops.
- **Resilient Timeout Handling:** Sets transfer timeouts to 5000 ms and gracefully retries transient `G_USB_DEVICE_ERROR_TIMED_OUT` conditions during idle polling and background calibration refreshes, while aborting immediately on cancellation.
- **Tuned PAM Integration:**
  - Configures `max-tries=3 timeout=20` for fingerprint retries across `sudo` and Polkit.
  - Configures `timeout=-1` on `gdm-fingerprint` so the login screen waits indefinitely for a touch without timing out.
  - Bypasses `pam_fprintd.so` inside `gdm-password` so password logins are instantaneous without blocking on `fprintd`.
- **APT-Safe Debian Packaging:** Built with package epoch `2:1.94.10-2+elanpress` so routine `apt upgrade` runs do not overwrite the driver with distribution stock versions (`1:x`).

---

## Supported Hardware

| USB ID | Hardware Model / Laptop | Driver Architecture | Status |
|---|---|---|---|
| `04f3:0903` | ASUS VivoBook 16X (`M1603QA`) & compatible ELAN touch sensors | `elanpress` (`FP_SCAN_TYPE_PRESS`) | Verified |
| `04f3:0c6e` | ASUS ROG Flow X13 and compatible models | `elanpress` (`FP_SCAN_TYPE_PRESS`) | Supported |
| `04f3:0c4f` | Acer Aspire A515-45 and compatible models | `elanpress` (`FP_SCAN_TYPE_PRESS`) | Supported |
| `04f3:0c63` | ELAN Touch Series | `elanpress` (`FP_SCAN_TYPE_PRESS`) | Supported |

---

## Installation

### Quick Install (Debian / Kali / Ubuntu)

Download or clone the repository and install the release `.deb` package:

```bash
sudo apt install ./releases/libfprint-2-2_2.1.94.10-2+elanpress_amd64.deb
```

Alternatively, run the installer script:

```bash
sudo ./scripts/install.sh
```

> [!NOTE]
> Reboot or restart GDM after installation so updated PAM rules take effect on the login screen.

### Enroll & Verify

Enroll your fingerprint using 12 touches at slightly varied angles:

```bash
fprintd-enroll
```

Verify fingerprint matching:

```bash
fprintd-verify
```

---

## Note on GNOME Keyring

On Linux, GNOME Keyring (`login.keyring`) is encrypted with your login password. When logging in with a fingerprint, PAM does not have your plaintext password in memory to decrypt the keyring automatically, which may cause browsers or IDEs to prompt for the keyring password after graphical login.

- **Seamless Touch Login:** Open **Passwords and Keys** (`seahorse`), change the password on the **Login** keyring, and leave the new password blank so applications unlock it silently.
- **Password-Protected Keyring:** Log in using your password once at cold boot (unlocking the keyring for the session), then use your fingerprint sensor for lockscreen unlock (`Win + L`), `sudo`, and administrative prompts.

See [TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) for detailed keyring recovery steps.

---

## Building from Source

Install the required build dependencies:

```bash
sudo apt update
sudo apt install -y build-essential meson ninja-build pkg-config \
    libusb-1.0-0-dev libglib2.0-dev libgudev-1.0-dev libgusb-dev \
    libpixman-1-dev libssl-dev libcairo2-dev gobject-introspection \
    libgirepository1.0-dev dpkg-dev
```

Compile and generate the `.deb` package:

```bash
./packaging/build-deb.sh
```

---

## Rollback

To restore the distribution's default `libfprint-2-2` package and original PAM configuration:

```bash
sudo ./scripts/rollback.sh
```

---

## Documentation

- [Installation & Build Guide](docs/INSTALLATION.md)
- [Troubleshooting Guide](docs/TROUBLESHOOTING.md)
- [System Architecture](docs/ARCHITECTURE.md)
- [Hardware Inventory](docs/HARDWARE_INVENTORY.md)
- [Windows Driver Reverse Engineering](docs/REVERSE_ENGINEERING.md)
- [Security Model](docs/SECURITY.md)
- [Verification & Test Report](docs/TEST_REPORT.md)

---

## Acknowledgments & License

- Built on upstream [`libfprint`](https://gitlab.freedesktop.org/libfprint/libfprint) and the [`elanpress`](https://github.com/filip-rs/libfprint/tree/elanpress) driver architecture (Copyright © 2026 Filip Spanne).
- Licensed under the **GNU Lesser General Public License v2.1 or later (LGPL-2.1+)**. See [LICENSE](LICENSE) for full license terms.
