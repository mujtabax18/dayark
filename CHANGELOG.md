# Changelog

Notable changes are recorded here. Older entries are summarized from the maintainer's supplied release notes; entries after v0.0.38 reflect the supplied November development notes and source review, **not independently verified public binaries**.

## [Unreleased]

- Fix chat's shared scroll-controller assertion when toggling the sidebar or changing layout breakpoints; retain one message viewport and guard scroll reads during attachment transitions.
- Add a saved Enter to send switch under AI Settings → General. Shift+Enter inserts a newline; Ctrl/Cmd+Enter remains available.
- Open Models immediately with loading, error and Retry states; make AI settings return directly to the chat that opened it without switching the desktop settings section.
- Hide Back to DayArk on desktop sidebars and drawers while retaining mobile drawer navigation.

- Fix AI Chat startup blocking on GGUF verification/hardware detection: initialize native models and memory on request, bound required storage startup, and keep slow model preparation cancellable.
- Add Back to DayArk inside the AI chat sidebar/drawer, including during loading and errors. Keep the mobile toolbar menu button and return direct chat links to Home.

- Redesign AI chat for phones and desktop with a collapsible/resizable sidebar, optional runtime inspector, compact composer and keyboard controls.
- Restore offline/Ollama output budgets, reserve answer context, default native thinking off, reuse prompt prefixes and throttle RSS sampling.
- Add performance profiles, idle model release, bounded drafts/PDF extraction caching, bookmarks, notes/tags, prompt templates, branches and response versions.
- Add cancellation-safe redirect/answer-now, continuation and sequential editable message queues; retain partial responses and reject stale events.
- Add model-library search, sections, favourites, filters, sorting, comparison, storage totals and verified local GGUF import.
- Add code block copy/save/wrap/expand controls and preserve existing sync, model integrity checks and cloud consent.
- Add workspace, cache, queue, version, idle-release, import and responsive layout coverage; refresh stale GGUF/runtime test fixtures. See `docs/AI_WORKSPACE.md` for storage compatibility and remaining scope.

- Planned: broader cross-platform validation, UI and performance work, automated regression tests and continued Life Archive refinement.

## [0.0.39] — Proposed: 2026-11-08 — Open Source Beginning

### Open source and community
- Begin the transition from a release-only, proprietary repository to an openly published Flutter project.
- Add a personal project story, updated README, contribution instructions, proposed MIT license, roadmap, security guidance and release checklist.
- Make the project's development limitations, feature status and platform test requirements visible.

### Life Archive and recent functionality
- Life Archives bring together people, relationships, visual family/life networks, memories, albums and events.
- More responsive Life Archive desktop layout, searchable archive/album/event views and in-workspace details inspectors.
- Improvements to family relationship creation, spouse/child/sibling linking, duplicate avoidance and graph performance.
- Link memory albums and scanned document libraries into Media Studio without moving or duplicating their original records.
- Life Archive now follows global DayArk appearance; existing five theme presets remain available.

### Previously documented improvements included in the current source
- TLS-protected local sync with certificate-pinned pairing; fixed port 39393.
- Password-protected portable backups with legacy import compatibility.
- Refactoring of large Dart files and backup/restore safety and dialog fixes.

### Cleanup performed in the prepared source preview
- Remove an unused `life_archive_appearance_page.dart` file left behind after the separate appearance feature was retired. No active import was found in the supplied source; source regression check then passes.

### Known limitations before publishing
- The newer full project archive includes `pubspec.yaml`, platform folders and graph assets; the source has not been compiled/tested on target devices here.
- The bundled constellation JavaScript test now resolves the actual graph HTML asset; source-level checks pass.
- Removed signing secrets and generated files from the sanitized public source copy. Added one cross-platform release builder, GitHub Actions draft-release workflow, updated `.gitignore`, signing-friendly debug Gradle setup and automation guide.
- Full Flutter analysis, tests and real-device upgrade/sync/backup tests are still required.

## [0.0.38] — 2026-10-08

- Fixed Pending/Sent/Received/Conflict sync counters; improved incremental and initial synchronization, data duplication avoidance and general stability.

## [0.0.37] — 2026-10-08

- Added Android, Windows and Linux support in the published release notes.
- Migrated SQLite access from `sqflite` to Drift.
- Introduced LAN device pairing and synchronization; included a database reset option.
- Family and Memories modules were noted as under development.

## [0.0.36] — 2026-08-30

- Added online quotation library with offline access; home layout customization and tutorial improvements; duplicate protection and database reliability changes.

## [0.0.35] — 2026-08-29

- Added persistent preferences for startup update checks and a “Never show again” update prompt option.

## [0.0.34] — 2026-08-29

- Added habit editing and a combined home calendar for diaries, habits, chores, groceries, loan due dates and medication reminders.

## [0.0.33] — 2026-08-29

- First public Android APK, with core diary, tasks, habits, reminders, expenses, notes/documents and local-first data management.
