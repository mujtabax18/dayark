# Family tree: visual, one-step relationship builder

## What changed

- New trees start with one person (name required, photo optional) and open automatically.
- Existing trees display compact previews with member photographs and relationship counts.
- The tree canvas displays **all** stored relationships, not only parents and guardians.
- Parent and guardian generations appear above/below, siblings and spouses appear alongside, and related branches stay connected in one network.
- Every person has colored directional arrows: **top = parent, bottom = child, left = sibling, right = spouse**.
- Tap an arrow to add a relative with a name and optional photo, or link an existing person instead of creating a duplicate.
- The quick-add dialog also supports partners, guardians, dependents, and other relatives.
- Tap any person to refocus the network around them. Use the info icon to open their complete profile.
- Zoom/pan/center controls remain available. Relationship lines use color-coded, directional arrowheads.
- Atomic database transactions protect new-tree+root and new-person+relationship creation.

## Integration

Replace the existing `lib/` contents with the files inside this archive (the ZIP starts at the `lib/` directory contents). No schema migration or new package dependency is required. Existing database records, profile editing, memories, and relationship management remain supported.

## Manual checks

1. Create a tree with a name, starter person, and optional photo. Verify the first card is displayed immediately.
2. Use each of the four arrows to add parent, child, sibling, spouse. Confirm node positions and connector colors.
3. Focus on a spouse, add their parents, then switch focus between people to see both families.
4. Link an existing member rather than creating a duplicate. Confirm links and records persist after reopening.
5. Use the info icon and People/Memories tabs to edit or remove existing records.
6. Test pinch-to-zoom and drag-to-pan on Android and mouse/trackpad on Linux.

> Note: Code inspection and static checks were possible in this environment, but a Flutter SDK/build environment was not available here; run `flutter analyze` and test on both of your platforms before publishing.
