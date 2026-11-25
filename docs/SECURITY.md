# Security, Biometrics & Authentication Architecture

## 1. Authentication Integration Strategy

The fingerprint authentication subsystem operates via standard Linux PAM (Pluggable Authentication Modules) utilizing `pam_fprintd.so`.

### PAM Stack Verification
The primary authentication block in `/etc/pam.d/common-auth` is configured as follows:
```pam
# here are the per-package modules (the "Primary" block)
auth    [success=2 default=ignore]    pam_fprintd.so max-tries=1 timeout=10 # debug
auth    [success=1 default=ignore]    pam_unix.so nullok try_first_pass
# here's the fallback if no module succeeds
auth    requisite                     pam_deny.so
# prime the stack with a positive return value if there isn't one already
auth    required                      pam_permit.so
```

### Password Fallback Guarantee
- If fingerprint matching fails, or times out (10s), or the USB sensor is disconnected or idle, `pam_fprintd.so` returns `default=ignore`.
- Execution immediately drops through to `pam_unix.so` (standard password authentication).
- Under no circumstance can a fingerprint driver crash or failure lock the user out of the machine.

---

## 2. Biometric Data Confidentiality & Storage

1. **Storage Location:** 
   Enrolled biometric feature templates are serialized and stored in:
   `/var/lib/fprint/<username>/`
2. **Access Control:**
   - Permissions: `0700` for directory, `0600` for print files, owned by `root:root`.
   - Ordinary non-root processes cannot read or inspect print templates directly.
3. **No Raw Image Retention:**
   - Raw capacitive image frames are processed in memory and immediately discarded.
   - Only scale-invariant feature transform (SIFT) keypoint vectors (scale, orientation, and 128-byte gradient histograms) are retained.
   - Raw images cannot be reconstructed from SIFT keypoint descriptors.
4. **Log Sanitization:**
   - Neither debug logs (`journalctl`) nor daemon telemetry store raw pixel buffers, keypoint vectors, or cryptographic secrets.
   - Only state transitions, match scores, and status codes are reported.

---

## 3. Biometric Security Model vs. Passwords

Fingerprints and passwords fulfill distinct roles in Linux security:
1. **Convenience & Quick Unlock:** Fingerprint authentication is ideal for screen unlock (GNOME Shell / GDM) and non-destructive `sudo` operations.
2. **Distinct Security Boundary:** Fingerprint authentication does **not** decrypt full-disk encryption (LUKS), unlock the GNOME Keyring, or perform pre-boot authentication. Password entry is still required at initial boot to derive cryptographic keys for filesystem and keyring decryption.
3. **Rollback Procedures:**
   If at any point fingerprint authentication is not desired:
   ```bash
   sudo pam-auth-update
   ```
   Uncheck *"Fingerprint authentication"* and press OK.
