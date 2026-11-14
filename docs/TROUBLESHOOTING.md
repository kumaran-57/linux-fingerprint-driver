# Troubleshooting Guide: ASUS VivoBook 16X Fingerprint Sensor

## 1. Diagnostic Matrix & Common Issues

---

### Issue 1: "The password you use to log in to your computer no longer matches that of your login keyring" on Opening Apps
- **Symptoms:** You log in to your desktop using the fingerprint sensor. When opening apps like Antigravity IDE, Google Chrome, or VS Code, a dialog appears stating *"The password you use to log in to your computer no longer matches that of your login keyring"* or asking for your keyring password. If you enter your password it may fail, but locking (`Win + L`) and unlocking with your password fixes it.
- **Root Cause:**
  - Linux `gnome-keyring` encrypts saved credentials and API tokens on disk using your user login password.
  - When you log in with a password, PAM passes your password in plaintext to `pam_gnome_keyring.so`, which decrypts the keyring in memory.
  - When you log in with a **fingerprint**, PAM verifies your physical identity, but neither the sensor nor PAM possesses or stores your plaintext password. The keyring remains locked on disk.
  - When an application requests access to the Secret Service API, GNOME Keyring prompts for the decryption password. If GDM attempted an empty authentication token, the dialog shows a mismatch. Unlocking from the lock screen (`Win + L`) with your password resolves it because PAM receives your plaintext password and unlocks the keyring.
- **Permanent Solution A (Recommended for Full Fingerprint Automation):**
  Set your keyring password to blank (empty):
  1. Open the **Passwords and Keys** application (`seahorse` in terminal).
  2. Under *Passwords*, right-click **Login** (or **Default**) and click **Change Password**.
  3. Enter your current password.
  4. Leave the **New Password** field completely blank and click **Continue**.
  5. Confirm *"Use Unsafe Storage"*.
  *Result: The keyring unlocks automatically on session start without ever asking for a password, even when logging in via fingerprint.*
- **Permanent Solution B (Security-Conscious):**
  Log in using your password once upon cold boot (which unlocks the keyring for your entire desktop session), then use the fingerprint sensor for:
  - Screen unlock (`Win + L`)
  - Terminal `sudo`
  - Polkit elevation dialogs

---

### Issue 2: Spurious Timeouts Without Touching the Sensor
- **Symptoms:** When running `fprintd-verify` or `sudo`, the sensor times out almost immediately without touching the finger, or aborts with `verify-unknown-error`.
- **Root Cause:**
  - In earlier `elanpress` versions, `ELANPRESS_IDLE_POLL_INTERVAL_MS` was set to 5ms. At ~18 KB per frame, this pushed ~3.7 MB/s across a 12 Mbps Full Speed USB link (bandwidth limit ~1.5 MB/s), causing buffer overflow and frame drops.
  - Furthermore, `ELANPRESS_FRAME_TIMEOUT` was set to only 2000ms, and any transient USB timeout during idle polling terminated the entire verification state machine.
- **Solution:**
  - Install the latest `.deb` package (`libfprint-2-2_2.1.94.10-1+elanpress_amd64.deb`).
  - Polling interval is paced at 40ms (~25 fps, ~35% bus utilization), and transient timeouts during idle waiting are gracefully retried rather than aborting verification.

---

### Issue 3: Driver Disappears After a Few Days / After `apt upgrade`
- **Symptoms:** Fingerprint authentication works for a few days, then suddenly stops working and reverts to swipe errors ("swipe too short").
- **Root Cause:**
  - A manual copy created `/usr/lib/x86_64-linux-gnu/libfprint-2.so.2.0.0.stock-backup`. When `ldconfig` ran during maintenance, it saw both files with SONAME `libfprint-2.so.2` and switched the symlink back to the stock backup.
  - Regular `apt upgrade` replaced unversioned manual files with the distribution package `1:1.94.10-1`.
- **Solution:**
  - The provided Debian package (`libfprint-2-2_2.1.94.10-1+elanpress_amd64.deb`) uses epoch `2:`, making it strictly higher than Debian's `1:`. `apt upgrade` will never overwrite it.
  - The package's `preinst` and `postinst` automatically remove or relocate any rogue `.stock-backup` file from the dynamic linker path.

---

### Issue 4: "fprintd-enroll says 'swipe too short'"
- **Cause:** System is running the stock `elan.c` swipe driver.
- **Solution:** Verify with `./linux-fingerprint-driver/scripts/check_support.sh`. Install the patched `.deb` package:
  ```bash
  sudo apt install ./linux-fingerprint-driver/releases/libfprint-2-2_2.1.94.10-1+elanpress_amd64.deb
  ```

---

### Issue 5: Fingerprint Enrolled, but Login Screen Has No Fingerprint Prompt
- **Cause:** PAM has not enabled `pam_fprintd.so`.
- **Solution:**
  ```bash
  sudo pam-auth-update
  ```
  Ensure `[*] Fingerprint authentication` is enabled (spacebar to toggle, Tab to Ok).

---

## 2. Emergency Recovery & Rollback

If you need to quickly return to the default distribution state:
```bash
sudo ./linux-fingerprint-driver/scripts/rollback.sh
```
