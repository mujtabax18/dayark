# Dayark – Local Sync Update

### What's Changed
- Added secondary device QR generation for Linux and other devices.
- Improved access to Local Device Sync on mobile.
- Added Cancel Pairing Code for both primary and secondary devices.
- Cancelling pairing returns the device to Standalone mode and re-enables all pairing options.
- Existing sync data and connected devices remain unaffected.

**Note:** Back up important data before updating.


# Dayark — Family Tree Updates

A faster, visual family tree builder for Android and desktop. Create people and connect relatives directly on an interactive relationship canvas without manually managing every connection.

## What's New

### 1. Easier Tree Creation
- View existing family trees with member/photo previews, or create a new one.
- Start with a **tree name** and the **first person's name**; a photo is optional.
- The starting person is created automatically, and the tree opens immediately.
- Continue using existing people, profile editing, memories, and relationship tools.

### 2. Interactive Relationship Canvas
- Each person appears as a selectable node; an available photo appears on the node.
- Add relatives using directional controls:
    - **↑ Parent** — positioned above.
    - **↓ Child** — positioned below.
    - **← Sibling** — positioned alongside.
    - **→ Spouse** — positioned beside the person.
- Color-coded connections make relationship types easier to distinguish.
- Tap any member to focus the tree around them, including a spouse's extended family.
- Pan, zoom, and recenter to explore connected branches.
- Create a new relative or link an existing person without duplicating their record.

### 3. Automatic Spouse & Child Linking
- When adding a **spouse**, **Share existing children with this spouse** is enabled by default.
- When adding a **child** to someone with an existing spouse, **Link children to both spouses** is enabled by default.
- Children remain **one person/node**, connected to both parents through separate relationship links.
- Disable sharing for stepfamilies or situations where parent relationships differ.
- Works when connecting people who already exist in the same tree.

### 4. Automatic Parent Sharing for Siblings
- If the selected person has parents, adding a sibling shows **Use the same parents**, enabled by default.
- When enabled, the new or existing sibling is linked to the selected person's existing parent records.
- When disabled, only the sibling relationship is added; no parents are automatically assigned.
- If only one parent exists, only that parent is shared. If no parent exists, the option is hidden.
- Available in both **Quick Add** and **Add Relationship** flows.

### 5. Performance & Feedback
- Cache graph layout until members, connections, or the focused person change.
- Reduce repeated rendering work and expensive synchronous image checks.
- Refresh only the relationship data needed after quick changes.
- Keep the tree visible while updates run, with **Updating family connections** progress feedback.
- Show saving/linking progress in add-person and relationship forms instead of an abrupt screen flash.

## Data Integrity & Compatibility

- Relationship updates are transactional to avoid partially saved connections.
- Reuse existing person IDs; prevent duplicate relationship rows and parent/child ancestry cycles.
- Existing family trees, profiles, and memories are preserved.
- **No database migration or new Flutter dependency required.**
- Previously saved spouse/child connections are **not automatically backfilled**; reapply the relationship with sharing enabled to add missing parent links.


# DayArk – Secure LAN Sync Update

This update improves the **security and reliability** of local synchronization between devices.

### What's New
- **Encrypted Sync:** HTTPS/TLS now protects all device synchronization.
- **Secure Pairing:** Improved QR pairing with certificate verification.
- **Android–Linux Fix:** Resolved the `CANNOT_PARSE_LEAF_CERT` TLS handshake issue.
- **Fixed Port:** All platforms now use TCP port `39393`.
- **Reliable Sync:** Existing backups, incremental updates, and conflict handling remain supported.

### Important Update Notes
- Update both devices and pair them again using a new QR code.
- Allow TCP port `39393` through your computer's firewall if required.
- Back up important data before updating.

**Supported Platforms:** Android, iOS, Linux, Windows, and macOS. Cross-platform testing is recommended.



# DayArk Update – Secure Backups

### What's New

- **Password-protected backups:** New backups are encrypted to keep your data private.
- **Easy restore:** Restore encrypted backups using your password.
- **Backward compatibility:** Older ZIP, JSON, and SQLite backups are supported on a separate compatibility page.
- **Navigation fixed:** Fixed the compatibility page opening Home instead of the correct screen on Linux.

**Important:** Keep your backup password safe. You'll need it to restore encrypted backups.



# DayArk – Update Notes
**Date:** October 19, 2026

## What's Updated
- Refactored 26 large Dart files into 67 smaller, organized components for easier maintenance.
- Improved code structure and readability for open-source contributors.
- Fixed backup password dialog controller disposal issues.
- Fixed backup dialog layout overflow.
- Improved encrypted backup restoration error handling and password retry flow.
- Preserved existing functionality, database structure, encryption, and backward compatibility.
- Added regression tests and architecture documentation.

## Verification
- Passed source integrity and Dart part-reference checks.
- Full Flutter runtime and cross-platform testing still required.

## Documentation
- Updated `README.md` and `changes.md`.
- Added `ARCHITECTURE.md` and regression tests.

**Goal:** Improve maintainability, stability, and open-source readiness without affecting existing functionality.