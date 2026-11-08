# Contributing to DayArk

Thank you for considering a contribution. DayArk began as one person's personal project, and helpful improvements of any size are welcome. You do **not** need to write a huge feature to make a difference.

## Contributions especially welcome

- **UI/UX redesign:** The maintainer is not a designer. Improve clarity, responsive layouts, navigation, theming, accessibility and visual consistency without removing features.
- **More themes:** DayArk already has five accent presets; extend/customize the system rather than introducing a second disconnected theme implementation.
- **Performance:** Reduce slow first loads, unnecessary rebuilds, oversized widgets, repeated database queries and expensive sync operations.
- **Testing:** Flutter unit/widget/integration tests; Android/Linux/Windows smoke tests; backup/restore and LAN synchronization tests.
- **Documentation, localization and accessibility:** All help is valuable.
- **Bug fixes and security hardening:** Especially data integrity, backup safety, sync conflicts and input validation.

The [roadmap](ROADMAP.md) lists longer-term ideas. Please open an issue or discussion before starting a large new module.

## Before you start

1. Check existing issues and PRs for duplicates.
2. For small fixes, feel free to submit a focused PR. For broad redesigns, database changes, sync protocol changes or new dependencies, propose the approach in an issue first.
3. **Never attach personal DayArk databases, photos, backups, credentials, financial records or other private user data.** Create fictional test data instead.
4. Respect the existing local-first design and offline use cases. New cloud services, analytics, paid features or mandatory accounts require explicit maintainer discussion.

## Development setup

Use the **complete Flutter repository** with Flutter 3.47.9 (see `.fvmrc`):

```bash
git clone https://github.com/mujtabax18/dayark.git
cd dayark
flutter doctor
flutter pub get
flutter analyze
flutter test  # when the full project's Flutter test directory is available
```

Use `flutter run -d linux`, `flutter run -d windows`, or an Android/iOS device ID where the platform is configured. **Android debug builds do not require a signing key.** Never ask for or commit the maintainer's private keystore. Desktop/Android release packaging is documented in [release automation](docs/RELEASE_AUTOMATION.md). Some features require extra native dependencies or assets. The current internal Dart import prefix is `package:metersystem/...`; do not globally rename it in an unrelated PR.

Source-only regression scripts in the uploaded snapshot can also be run as follows, **after locating their paths in the complete repository**:

```bash
python lib/qa/test_life_schema.py
python lib/qa/test_life_archive_inspector.py
python lib/qa/test_life_archive_desktop_ui.py
python lib/qa/test_media_archive_links.py
```

These tests inspect source/SQLite behavior. They do not replace Flutter tests or device verification. The constellation JavaScript test uses `assets/family_tree/relationship_universe.html` from this repository; run it with `node lib/qa/test_life_constellation.cjs`.

## Coding guidelines

- Prefer **small, focused Dart files** with clear separation of UI, state, repositories and persistence. Avoid adding more responsibilities to large state/services classes.
- Preserve existing behavior and database compatibility unless a documented migration is required.
- Keep platform differences explicit. Test native file access, images, and package integrations on relevant devices.
- Centralize repeatable UI design patterns and strings rather than hardcoding new variants everywhere.
- Format touched code with `dart format`; run `flutter analyze` and applicable tests.
- For database/schema work, include migration, rollback/recovery considerations and tests against existing data.
- For sync changes, test duplicates, disconnected devices, conflict resolution, reconnects and mixed versions; never downgrade encryption or disable certificate verification to get a connection working.
- For backup/restore changes, test corrupted files, incorrect passwords, old formats, low disk space and interrupted restores.

## Pull requests

Include **what changed, why, how it was tested**, and any compatibility or migration notes. For UI changes, add before/after screenshots if possible. For user-facing changes, update `README.md`, `CHANGELOG.md`, or the relevant documentation.

Keep PRs focused where practical. An unfinished idea is welcome in an issue; merged code should have reasonable failure handling and avoid mock success behavior presented as completed functionality.

## Reporting bugs

Please provide DayArk version, OS and version, app installation method, steps to reproduce, actual vs expected results, and a **sanitized** log or screenshot. See the issue template.

## Security

Do not disclose a vulnerability publicly before the maintainer can review it. Follow [SECURITY.md](SECURITY.md). Never include sensitive data or copies of private encryption keys.

## Community

Be respectful, patient and constructive. Different levels of skill, different languages, and new contributors are welcome. Criticize code or design, not people. Nobody is expected to work for free or to provide ongoing support.

**Thank you for making DayArk better.**
