# Family tree — Couple layout correction

## Issue

The old layout assigned a grid cell to each person separately. A sibling
could therefore be placed between someone and their spouse, particularly when
a parent linked both siblings. The spouse connector could also pass behind
another person's card.

## Change

- `view/parts/family_relationship_canvas_layout.dart` now lays out spouses
  and partners as contiguous household units before it places other relatives.
- Units reserve the full width they need, so no sibling, parent, child, or
  orphan can be inserted between partners.
- Parents remain above children and sibling groups remain on the same row.
- Couples have closer horizontal spacing than separate households, making
  marriage links easier to read.
- Every family member still appears once. All relationships, details,
  2D/3D display, pan, zoom and full-screen controls are unchanged.
- The layout was separated from the canvas state file for maintainability.

## Manual regression checklist

1. Add two parents, two children (siblings), and a spouse to one child.
   Verify the child and spouse appear together with the other sibling outside
   the couple.
2. Select each person as the focus. The couple must stay adjacent.
3. Add a spouse to the other sibling, then a child to each couple. Verify
   generations, spacing and link lines.
4. Open full screen, pan and zoom in 2D and 3D.
5. Check one-person trees and disconnected people.

No database changes or migrations are required. The code uses only Flutter.
