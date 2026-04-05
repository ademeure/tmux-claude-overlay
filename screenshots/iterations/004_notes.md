## Iteration 004 — Overflow protection + narrow mode fix (catppuccin)

### Changes Made
- Sessions card now caps content based on available screen rows
- Prevents footer from rendering inside card borders
- Tested at both 110x40 (wide) and 80x30 (narrow)

### 110x40 Wide Mode
- Two-column layout: Git (left) + System (right) with 1-char gap
- Sessions card full width below
- Footer hugs content with 1 blank row spacing
- All borders aligned, ╌ separators clean
- Column heights balanced
- Rating: 9/10

### 80x30 Narrow Mode
- Single-column layout: Git → System → Sessions stacked
- Sessions card shows 2 entries (limited by screen height)
- Footer draws cleanly below the Sessions card
- All borders aligned
- Rating: 8.5/10

### Remaining Polish Opportunities
1. The dashed separator `╌` line extends 1 char too far (there's a space + `│`
   after it, vs content which has text + padding + space + `│`). This is actually
   correct padding — the card format is `│ content_area │` with 1 space on each side.
   The ╌ fills the content_area exactly. Looks fine.

2. In narrow mode, "Terminal Dashboard" title is slightly left of center because
   the screen is 80 cols but the banner centering doesn't account for the padding.

3. The stat row labels ("Branch", "Sessions", etc.) could be dimmer to create
   more contrast with the values below them.

### Overall Quality: 8.5/10
The layout is now robust across different terminal sizes and adapts gracefully.
