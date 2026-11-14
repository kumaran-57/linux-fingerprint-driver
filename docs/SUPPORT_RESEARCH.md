# Open-Source Support Research & Driver Comparison

## 1. Executive Summary
The target device is an **ELAN:Fingerprint** touch sensor (`04f3:0903`) installed in an **ASUS VivoBook 16X** (`VivoBook_ASUSLaptop M1603QA_M1603QA`).

Our research into upstream `libfprint`, historical forks, community issues, and Linux biometric drivers reveals a fundamental architectural mismatch:
1. **The Upstream Flaw:** In official upstream `libfprint` (from `v0.8.3` through `v1.94.10`), device `04f3:0903` is bound to the legacy `elan.c` driver.
2. **The Swipe vs. Touch Mismatch:** The legacy `elan.c` driver hardcodes:
   ```c
   dev_class->scan_type = FP_SCAN_TYPE_SWIPE;
   ```
   The driver expects the user to drag their finger across the sensor, records 7 to 30 frames (`ELAN_MIN_FRAMES = 7`), clips frame height to 50 pixels (`ELAN_MAX_FRAME_HEIGHT = 50`), and runs movement estimation (`fpi_do_movement_estimation`) to stitch slices into a synthetic image for NIST NBIS minutiae matching.
3. **The User Experience Failure:** Because the physical sensor on the ASUS VivoBook 16X is an **area touch / press sensor** (not a swipe strip), a user naturally taps or rests their finger. The legacy driver either aborts with `FP_DEVICE_RETRY_TOO_SHORT` ("swipe too short: want >= 7 frames, got 1") or produces distorted, unmatchable stitched images. This explains why users on Debian, Kali, Ubuntu, Fedora, and Arch report that `04f3:0903` either completely fails to verify or has near-zero recognition reliability.
4. **The Modern Touch Solution (`elanpress`):** In 2024–2026, Linux developers (e.g. Filip Spanne in the `elanpress` implementation) reverse engineered the true Windows Hello behavior for ELAN touch sensors (`04f3:0c6e`, `04f3:0c4f`, `04f3:0c63`). These sensors share the exact same USB command protocol (`0x40 0x31` LED, `0x00 0x09` image, `0x00 0x0c` sensor dimensions) and endpoint mapping (EP 1 OUT, EP 3 IN, EP 2 IN). The `elanpress` architecture replaces broken swipe stitching with:
   - Native `FP_SCAN_TYPE_PRESS` semantics.
   - Touch detection via pixel contrast delta against background.
   - Multi-stage enrollment (12 touches covering different finger orientations, exactly reproducing Windows Hello enrollment).
   - In-driver SIFT/keypoint extraction and rigid placement matching (Lowe's ratio test + least-squares alignment), which achieves reliable matching on small capacitive sensor matrices where standard minutiae (NBIS) fail.

## 2. Compatibility & Implementation Comparison Matrix

| Hardware ID | Implementation | Source Repo / Branch | Driver Architecture | Scan Type | Matching Method | Known Limitations | Status on VivoBook 16X |
|---|---|---|---|---|---|---|---|
| `04f3:0903` | `elan.c` (stock) | `gitlab.freedesktop.org/libfprint/libfprint` | `FpImageDevice` (USB) | `SWIPE` (Incorrect) | Host Minutiae (NBIS / bozorth3) | Fails on tap; requires swiping; severe false-rejection rate | Installed in Kali `1:1.94.10-1`; fails touch UX |
| `04f3:0903` | `iafilatov/libfprint` | `github.com/iafilatov/libfprint` (Historical) | `FpImageDevice` (USB) | `SWIPE` | Host Minutiae (NBIS) | Unmaintained; merged into upstream in 2017; swipe-based | Obsolete |
| `04f3:0c6e`, `04f3:0c4f`, `04f3:0c63` | `elanpress` | `github.com/filip-rs/libfprint` (`elanpress`) | `FpDevice` (USB) | `PRESS` (Touch) | Local Keypoints (SIFT + RANSAC) | Device table previously lacked PID `0x0903` | Direct architectural candidate for porting `04f3:0903` |
| `04f3:*` (TOD) | `libfprint-2-tod1-elan` | OEM Binary Blob (HP/Lenovo) | Proprietary TOD plugin | `PRESS` | Proprietary closed-source blob | Distributed only for select OEM PIDs; no public support for ASUS `0903` | Not available for `04f3:0903` |

## 3. Protocol & Sensor Analysis

### 3.1 Device Communication Specifications
- **Transport:** USB 2.0 Full Speed (12 Mbps) bulk transfers.
- **Endpoints:**
  - `0x01` (EP 1 OUT): Command submission endpoint (2 bytes commands).
  - `0x83` (EP 3 IN): Command response endpoint (1 to 4 bytes response).
  - `0x82` (EP 2 IN): Raw 14-bit image frame stream (2 bytes per pixel, big-endian / vertical format).

### 3.2 Command Protocol Summary
| Command Opcode | Description | Response Length | Direction / Endpoint |
|---|---|---|---|
| `{0x40, 0x19}` | Get Firmware Version (`get_fw_ver`) | 2 bytes (big endian) | EP 3 IN |
| `{0x00, 0x0c}` | Query Sensor Matrix Dimensions (`get_sensor_dim`) | 4 bytes (`[width, _, height, _]`) | EP 3 IN |
| `{0x40, 0x31}` | LED / Activation Command (`cmd_led_on`) | Skip read | EP 1 OUT |
| `{0x00, 0x09}` | Capture Image Frame (`cmd_get_image`) | `width * height * 2` bytes | EP 2 IN |
| `{0x00, 0x0b}` | Deactivate / Standby (`cmd_stop`) | Skip read | EP 1 OUT |

### 3.3 Match-on-Host vs. Match-on-Chip
- **Finding:** The sensor `04f3:0903` is strictly **Match-on-Host**.
- It does **not** feature internal biometric template storage or a match-on-chip secure enclave (such as `elanmoc` or Synaptics Prometheus).
- Raw sensor frames are streamed across USB EP 2 to the host CPU, where minutiae or keypoint extraction and verification are computed.
- Security boundary: Biometric prints are serialized into standard `fprintd` storage (`/var/lib/fprint/`) protected by system user `root` permissions.

## 4. Upstream Status & Community Roadmap
- **Upstream Gitlab Issue:** The libfprint issue tracker has multiple open requests from users with Elan touch sensors on ASUS Vivobook and Zenbook laptops complaining of unresponsive or swipe-demanding sensors.
- Upstream `libfprint` has been hesitant to merge drivers that do custom image matching outside NBIS unless structured cleanly.
- The `elanpress` driver architecture provides a clean separation:
  - It handles touch polling, background subtraction, contrast checking, keypoint extraction, multi-stage enrollment, and matching within the `FpDevice` API.
  - Adding `04f3:0903` to `elanpress` and removing it from the legacy `elan.c` driver solves the problem completely and brings modern Windows Hello touch parity to ASUS VivoBook laptops.
