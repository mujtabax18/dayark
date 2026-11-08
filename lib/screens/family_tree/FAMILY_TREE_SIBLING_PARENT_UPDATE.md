# Family Tree – Same Parents for Siblings

## Changes

- When a selected person already has one or more parent connections, **Use the same parents** appears when adding a sibling. The switch is **on by default**.
- The switch is supported in **Quick Add / Grow the family** and the existing **Add relationship** dialog.
- ON creates parent -> new sibling connections using existing parent IDs. No parent or person is copied.
- OFF creates only the sibling link (helpful for half-siblings or stepfamilies).
- Supports both newly created siblings and people already in the tree; works regardless of the order of member IDs.
- All new relationships are saved in one transaction, with duplicate-link and ancestry-cycle checks.
- The earlier spouse/child connection behavior, loading indicators, and canvas optimizations remain unchanged.
- No database migration or additional Flutter package is required.

## Installation

Overlay the changed files into your Flutter project's `lib/` directory, preserving folder paths, or use the full updated `lib/` ZIP.

## Suggested tests

1. Create A, with parents P1 and P2. Add sibling B to A with **Use the same parents** ON. Expected: one B node, sibling A–B, parent links P1–B and P2–B.
2. Add sibling C to A with the switch OFF. Expected: only A–C sibling link, no P1/P2–C parent links.
3. Link an existing person D as A's sibling with the switch ON. Expected: D is not duplicated, only missing parent links added.
4. Add a sibling to an anchor with one parent: only that one existing parent is linked.
5. Add a sibling to a person without parents: the switch is hidden.
6. Open **Relationships > Add relationship**, choose **Is sibling of**, and check the same switch and behavior.
7. Repeat a sibling link: confirm no duplicate relationship rows.
8. Verify a relationship that would create a parent-cycle fails without partial saves.

> Build validation: run `flutter analyze` and test on Android/Linux. Flutter SDK was unavailable in the code-edit environment.
