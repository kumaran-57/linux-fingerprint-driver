# Hardware Inventory: ASUS VivoBook 16X Fingerprint Sensor

## 1. System & Host Overview
- **Laptop Model:** ASUS VivoBook 16X (Model: `VivoBook_ASUSLaptop M1603QA_M1603QA`)
- **System Vendor:** ASUSTeK COMPUTER INC.
- **Hardware Version / Revision:** 1.0
- **Product Family:** Vivobook
- **Motherboard:** M1603QA
- **BIOS Version:** M1603QA.308 (Release Date: 05/22/2023)
- **Processor:** AMD Ryzen 5 5600H with Radeon Graphics (6 cores / 12 threads, x86_64)
- **Host Architecture:** x86_64
- **Operating System:** Kali GNU/Linux Rolling (2026.3)
- **Debian Base:** Debian Testing / Unstable (`kali-rolling`)
- **Kernel Version:** `Linux devil 7.1.5+kali-amd64 #1 SMP PREEMPT_DYNAMIC Kali 7.1.5-1kali1 (2026-07-29) x86_64 GNU/Linux`
- **Desktop Environment:** GNOME Shell (XDG_CURRENT_DESKTOP=GNOME, Display Manager: GDM3)

## 2. Fingerprint Sensor Identification
- **Manufacturer:** ELAN Microelectronics Corp.
- **Reported Product Name:** `ELAN:Fingerprint`
- **USB Vendor ID (VID):** `0x04f3`
- **USB Product ID (PID):** `0x0903`
- **Hardware Revision (bcdDevice):** `1.70`
- **USB Specification:** USB 2.0 (Full Speed - 12 Mbps)
- **Physical Topology:** Bus 001, Device 002, Port 1-3 (routed via AMD Renoir/Cezanne USB 3.1 xHCI Controller `0000:03:00.3`)
- **Interface Class:** Vendor Specific (Class 255 / 0xff, SubClass 0, Protocol 0)
- **Endpoints (5 Bulk Endpoints):**
  - Endpoint `0x81` (EP 1 IN): Bulk, MaxPacketSize 64 bytes, Interval 1ms
  - Endpoint `0x01` (EP 1 OUT): Bulk, MaxPacketSize 64 bytes, Interval 1ms
  - Endpoint `0x82` (EP 2 IN): Bulk, MaxPacketSize 64 bytes, Interval 1ms
  - Endpoint `0x83` (EP 3 IN): Bulk, MaxPacketSize 64 bytes, Interval 1ms
  - Endpoint `0x03` (EP 3 OUT): Bulk, MaxPacketSize 64 bytes, Interval 1ms
- **Unrecognized USB Descriptor:** `09 21 10 01 00 01 22 15 00` (Elan proprietary HID/feature descriptor block)
- **Kernel Driver:** None bound (`Driver=[none]`). Communicates directly via libusb/usbfs from userspace.
- **Power Management:** Bus Powered (100 mA), Remote Wakeup supported, Autosuspending via udev/hwdb (`ID_AUTOSUSPEND=1`, `ID_PERSIST=0`).

## 3. Peripheral & Bus Discovery Findings
- **ACPI / SPI / I2C Inspection:**
  - Trackpad: `ASUE1305:00` (`04F3:3212` I2C HID Mouse/Touchpad) on `i2c-ASUE1305:00`.
  - The fingerprint sensor (`04f3:0903`) is distinct from the touchpad I2C device and is physically connected via an internal USB 2.0 link.
  - No ACPI or SPI bindings are utilized by this sensor (`ELAN7001` or `ELAN70A1` SPI rules do not apply to this USB model).

## 4. Current Linux Biometric Stack Status
- **Installed Packages:**
  - `libfprint-2-2`: `1:1.94.10-1` (Debian/Kali package)
  - `fprintd`: `1.94.5-4+b2`
- **D-Bus Service (`net.reactivated.Fprint`):**
  - Daemon status: Functional (`fprintd.service` starts on D-Bus activation, activates cleanly, and deactivates after 30s idle).
  - Detected Device: `Device at /net/reactivated/Fprint/Device/0`
  - Name reported by libfprint: `"ElanTech Fingerprint Sensor"`
  - Assigned Driver: `elan` driver in `libfprint`
  - Enrolled Fingers: None for current user (`devil`).
  - Stages for Enrollment: `6` stages reported.
  - **CRITICAL FINDING — Scan Type:** Reported as `"swipe"` (`net.reactivated.Fprint.Device.scan-type = "swipe"`).
    - The physical sensor on ASUS VivoBook 16X is an area **touch** sensor (square sensor embedded in the touchpad upper right corner), but the `elan` driver defaults or defines it as `swipe`.

## 5. Security & Authentication Configuration
- **PAM Configuration:**
  - `/etc/pam.d/common-auth` already contains:
    ```pam
    auth [success=2 default=ignore] pam_fprintd.so max-tries=1 timeout=10 # debug
    auth [success=1 default=ignore] pam_unix.so nullok try_first_pass
    ```
  - `/etc/pam.d/gdm-fingerprint` is configured with `pam_fprintd.so`.
  - Password authentication fallback (`pam_unix.so`) is verified present and active.

## 6. Confidence Assessment
| Component | Confidence | Evidence Source |
|---|---|---|
| Laptop Identity | HIGH (100%) | `/sys/class/dmi/id/*` |
| Sensor Hardware VID/PID | HIGH (100%) | `lsusb`, `lsusb -v`, `udevadm` (`04f3:0903`) |
| Physical Interface | HIGH (100%) | USB 2.0 Full Speed internal bus |
| Existing Driver Binding | HIGH (100%) | `fprintd-list`, `libfprint-2.so` strings, D-Bus introspection |
| Physical Sensor Type | HIGH (100%) | Touch sensor (physical hardware on ASUS VivoBook 16X touchpad) |
| Scan-type Mismatch | HIGH (100%) | D-Bus introspect reports `scan-type: "swipe"`, whereas device is physically touch |

## 7. Open Unknowns & Next Investigations
1. **Driver Implementation in libfprint:** How does libfprint's upstream `elan.c` configure device `04f3:0903`? Why is it classified as `FP_SCAN_TYPE_SWIPE` instead of `FP_SCAN_TYPE_PRESS`?
2. **Image Acquisition & Frame Dimensions:** What image dimensions (width, height) and frame format does `04f3:0903` produce? Does it require multi-frame stitching (swipe) or is it a single 2D image matrix (press/touch)?
3. **Firmware / Match-on-Chip:** Does `04f3:0903` perform match-on-host (sending raw image frames to libfprint/bochs-nbis) or match-on-chip (`elanmoc`)?
