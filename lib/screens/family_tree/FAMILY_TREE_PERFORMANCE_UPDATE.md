# Family Tree: faster canvas + shared spouse/child connections

## Updated behavior

- Caches the relationship graph layout until people, connections, or the focused person change.
- Removes the expensive dot-grid canvas painting and avoids synchronous per-node image existence checks.
- Keeps the current screen visible during graph refresh; shows an "Updating family connections" progress bar instead of a full-screen flash.
- Fetches only updated members and relationships after quick linking, rather than reloading memories and tree metadata.
- Shows save/link progress in the quick-add and relationship management forms.
- The new **Share existing children with this spouse** option is ON by default. It connects existing children from either spouse to both people using their existing member IDs.
- The new **Link children to both spouses** option is ON by default when adding a child to a parent who already has a spouse.
- The same rule applies when linking two existing people through the relationship manager.
- OFF preserves only the relationship you explicitly added (useful for stepfamilies / separate parentage).
- All relationship inserts use one transaction, ignore duplicate links and prevent parent/child cycles.

## Installation

Copy the `screens/family_tree` files into your Flutter project's `lib/screens/family_tree/`, keeping other app files unchanged. Alternatively overlay the full updated `lib/` archive onto your existing `lib/`. No additional dependencies or schema migrations.

## Test on Android and Linux

1. Run `flutter analyze` and a debug build.
2. Add Person A, and two children C1/C2. Add a new spouse B to A. Confirm **4 people**, spouse link A-B, and parent links A-C1, A-C2, B-C1, B-C2. No duplicates.
3. Add a child C3 to B. Confirm C3 is one person linked to both A and B.
4. Connect existing B (with two children) as A's spouse. Confirm the two children gain an additional parent link, not a second child record.
5. Turn sharing OFF when adding an additional child or spouse. Confirm only the explicit link is saved.
6. Repeat a spouse/child link: verify no duplicate relationship row or person appears.
7. Attempt a parent relationship that would cause an ancestry cycle: verify a clear error and transaction rollback.
8. Expand and re-center the canvas, change tabs, zoom and pan; confirm less UI stutter and an in-place progress bar while refreshing.

This change does not backfill child sharing across marriages that were already saved before this version. To share previously linked children, re-add an existing spouse connection with sharing enabled or use the relationship manager; already-existing spouse links are idempotent, and newly inferred parent links are inserted when you re-submit the connection.

Note: Flutter SDK was not available in the code-edit environment; run platform builds and the analyzer locally before release.
