# Universal Touch Fingerprint Compatibility Roadmap

## 1. Multi-Manufacturer Device Family Matrix

| Sensor Family / Manufacturer | Hardware IDs / Revisions | Transport Interface | Protocol Architecture | Firmware Dependency | Matching Location | Upstream Status |
|---|---|---|---|---|---|---|
| **ELAN Press / Touch Family** | `04f3:0903`, `04f3:0c6e`, `04f3:0c4f`, `04f3:0c63`, `04f3:0c5f` | USB 2.0 Bulk (EP 1 OUT, EP 3 IN, EP 2 IN) | Shared 2-byte opcode protocol (`0x40 0x31`, `0x00 0x09`) | None (Internal ROM) | Host (SIFT Keypoint Matching) | Patched via `elanpress` driver; pending upstream MR |
| **ELAN Match-on-Chip (MOC)** | `04f3:0c4b`, `04f3:0c4c`, `04f3:0c58` | USB 2.0 Bulk | Proprietary packet framing with session tokens | Internal Secure Enclave | On-Chip (Internal Template Gallery) | Supported by `elanmoc` driver in libfprint |
| **ELAN SPI Embedded Family** | ACPI `ELAN7001`, `ELAN70A1` | SPI / spidev | SPI bus transactions | Host firmware load | Host (libfprint `elanspi`) | Supported via `elanspi` in libfprint |
| **Goodix Match-on-Chip (MOC)** | `27c6:5110`, `27c6:530c`, `27c6:538d`, `27c6:639c`, `27c6:6594` | USB 2.0 Interrupt/Bulk | Goodix MOC protocol v1/v2 | Requires vendor firmware in `/lib/firmware/` for some PIDs | On-Chip / Host hybrid | Partial; community drivers (`libfprint-goodix`) |
| **Synaptics / Validity Touch** | `06cb:00bd`, `06cb:009a`, `06cb:00df` | USB 2.0 Bulk / Control | TLS encrypted session over USB (Prometheus) | TLS certificate pairing with host TPM | On-Chip | Supported in upstream `synaptics` driver |

---

## 2. Upstream Integration Strategy

1. **Target Upstream Project:** `libfprint` (Freedesktop project).
2. **Standardization Path:**
   - Integrate `elanpress` into `libfprint/drivers/meson.build` as a standard in-tree driver.
   - Update `autosuspend.hwdb` with unified `elanpress` PID mappings.
   - Ensure clean licensing under GNU LGPLv2.1+.
3. **Distribution Packaging Pipeline:**
   - **Debian / Kali:** Submit salsa.debian.org patch to `src:libfprint` package maintainers.
   - **Fedora / RHEL:** Copr repository integration -> Fedora rawhide package.
   - **Arch Linux:** Maintain in AUR (`libfprint-elanpress-git`) prior to upstream inclusion.

---

## 3. Legal, Licensing & Redistribution Constraints

- **Source Code License:** GNU Lesser General Public License v2.1 or later (LGPLv2.1+), matching `libfprint` upstream.
- **Reverse Engineering Legality:** Analysis performed solely for interoperability under EU Directive 2009/24/EC and US DMCA 17 U.S.C. § 1201(f) reverse engineering provisions.
- **No Proprietary Redistribution:** No proprietary Windows DLLs, firmware binaries, or reverse-engineered vendor intellectual property are redistributed. The implementation is 100% clean-room open-source C code.
