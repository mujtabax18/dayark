# DayArk architecture (source snapshot)

This document describes the structure visible in the provided Dart source. It is **not** a complete dependency/build guide; the original snapshot omitted `pubspec.yaml`, native project folders and assets.

## Technology

- **Flutter/Dart** for UI and most application logic.
- **Riverpod** for several application and screen state flows.
- **go_router** for application navigation.
- **Drift/SQLite** for local records, migrations and query access.
- **SharedPreferences** and secure storage for user settings and protected backup secrets.
- **Native platform integrations** for media access, local notifications, PDF editing, file selection, scanning and LAN communication.

## Key source folders

| Path in `lib/` | Responsibility |
| --- | --- |
| `main.dart` | Bootstrapping, settings, theme, localization and router |
| `core/design/`, `core/theme/`, `core/widgets/` | Design tokens, theme composition and reusable controls |
| `controller/` | App-level controllers/notifiers |
| `models/` | Data models and application state models |
| `screens/` | Modules for diary, family tree/Life Archive, media, tasks, money, utilities and settings |
| `services/db/` | Database initialization, migration and table SQL |
| `services/localDatabaseServices/` | Local data access and business operations |
| `services/device_sync/` | LAN device pairing, TLS and synchronization |
| `services/app_update/` | GitHub release checking/downloading |
| `services/backupService.dart`, `services/restoreService.dart` | Portable backup/restore integration |
| `services/portable_backup_crypto.dart` | Encrypted backup format/key derivation |
| `utlis/` | Routing, platform utilities and shared helpers (historic spelling retained) |

## Design guidance for contributors

Prefer small features that follow **UI → state/controller → service/repository → database** boundaries. Avoid tightly coupling persistence and platform resources to widget build methods. Existing source sometimes diverges from this ideal and can benefit from safe refactoring.

**Stability first:** Avoid changing database schemas, sync protocol state, backup structure or package identifiers without tests and migration documentation. For areas containing user-private information, maintain local-first behavior and explicit export/share permissions.

For contributing guidelines and suggested checks, see [CONTRIBUTING.md](CONTRIBUTING.md). For what has not been validated, see [OPEN_SOURCE_READINESS.md](OPEN_SOURCE_READINESS.md).
