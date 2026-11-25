# Protocol Reverse Engineering: Windows Driver Analysis

## 1. Architecture Research & Findings

### Q1: How does Windows communicate with the fingerprint sensor `04f3:0903`?
- **Answer:** Windows uses Microsoft's **WinUSB** kernel driver paired with an **Elan UMDF 2.19 (User-Mode Driver Framework)** user-mode USB driver (`WbfUsbDriver.dll`) and Windows Biometric Framework (WBF) adapter DLLs (`SensorAdapter.dll`, `EngineAdapter.dll`, `StorageAdapter.dll`).
- Communication occurs entirely via standard USB Bulk transfers across three endpoints. There is no custom kernel-mode driver, proprietary filter, or special ACPI interaction.

### Q2: What device interfaces and endpoints are used?
- **Answer:** As extracted via Ghidra static analysis of `WbfUsbDriver.dll`:
  - **BulkOutput Pipe (Write):** USB Endpoint `0x01` (EP 1 OUT). Transmits 2-byte command packets.
  - **BulkInput Pipe (Info):** USB Endpoint `0x83` (EP 3 IN). Receives synchronous command responses (1 to 4 bytes).
  - **BulkInput Pipe (Read):** USB Endpoint `0x82` (EP 2 IN). Streams raw capacitive sensor image frames (2 bytes per pixel).

### Q3: Does the device perform Match-on-Chip (MOC) or Match-on-Host?
- **Answer:** Match-on-Host.
  - The Windows driver package includes `EngineAdapter.dll` (and `VBSEngineAdapter.dll`), which explicitly handles image normalization, contrast enhancement, feature extraction, and biometric template matching on the host CPU.
  - No secure element or on-chip template store exists on PID `0x0903`.

### Q4: Does the sensor require downloadable firmware blobs?
- **Answer:** No.
  - The sensor contains internal ROM/Flash with factory firmware (reported as version `1.70` / `0x0170` via `bcdDevice` and `0x40 0x19`).
  - No external firmware upload sequence is initiated prior to normal operation.

### Q5: Why does Windows Hello work reliably as a touch sensor while Linux stock libfprint fails?
- **Answer:** 
  - Windows `WbfUsbDriver.inf` configures:
    - `AcceptSampleHint = 15` (multi-touch enrollment).
    - `CoveragePercent = 80`.
    - `EnrollAreaCenterCount = 6` (center presses, then peripheral angle touches).
  - The Windows engine accumulates multiple 2D touches into a multi-angle gallery, using local keypoint matching (similar to SIFT/SURF) rather than rigid minutiae alignment.
  - Stock `libfprint`'s `elan.c` incorrectly treated `04f3:0903` as a **swipe** sensor (`FP_SCAN_TYPE_SWIPE`), expecting fingers to move across the sensor, truncating height to 50 pixels, and demanding 7+ frames for stitching.

---

## 2. Static Analysis of Windows WHQL Driver

1. **Artifact Identification & Extraction:**
   - Windows 11 Driver CAB for ASUS VivoBook `04f3:0903`:
     `3.11.12011.10041` (WHQL certified, Elan Microelectronics).
   - Extracted components: `WbfUsbDriver.dll`, `SensorAdapter.dll`, `EngineAdapter.dll`, `WbfUsbDriver.inf`.
2. **PE Inspection & Symbol Mapping:**
   - Analyzed `SensorAdapter.dll` and `WbfUsbDriver.dll` via Ghidra.
   - Identified pipe setup strings and bulk transfers:
     - `0x18008bb00`: `BulkInput Pipe (Read) is 0x%p`
     - `0x18008bb40`: `BulkInput Pipe (Info) is 0x%p`
     - `0x18008bbc0`: `BulkOutput Pipe (Write) is 0x%p`

---

## 3. Protocol Description & State Flow

```
Host (Linux libfprint)                          Sensor (04f3:0903)
      |                                                 |
      | -------- [EP 1 OUT] {0x00, 0x0c} -------------> | (Query Sensor Dimensions)
      | <------- [EP 3 IN]  4 bytes [W, _, H, _] ------ | (e.g. 96x96)
      |                                                 |
      | -------- [EP 1 OUT] {0x40, 0x31} -------------> | (LED On / Activate Sensing)
      |                                                 |
      | === Polling Loop (every 40ms) ================= |
      | -------- [EP 1 OUT] {0x00, 0x09} -------------> | (Request Frame)
      | <------- [EP 2 IN]  W * H * 2 raw bytes ------- | (Raw frame)
      |                                                 |
      | Compute Frame Delta against Background:         |
      | If (coverage >= 12% && delta >= 1200):          |
      |     Touch Detected!                             |
      |     Wait settle delay (200ms)                   |
      |     Capture settling touch image                |
      |     Extract SIFT local keypoints                |
      | =============================================== |
      |                                                 |
      | -------- [EP 1 OUT] {0x00, 0x0b} -------------> | (Stop / Standby)
```

## 4. Verification Summary
- **Protocol Structure:** Standard USB bulk transfers, EP 1 OUT / EP 3 IN / EP 2 IN.
- **Hardware Architecture:** Match-on-Host, userspace libusb control via libfprint.
- **Porting Feasibility:** The `elanpress` driver codebase (`elanpress.c`, `elanpress-match.c`, `elanpress-sift.c`) natively implements this command sequence and supports `04f3:0903`.
