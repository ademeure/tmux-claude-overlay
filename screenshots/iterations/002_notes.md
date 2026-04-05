## Iteration 002 — Card-aware content padding (catppuccin, 110x40)

### Changes Made
- Added `card_print`, `card_kv`, `card_dots`, `card_text`, `card_status` helpers
- All content inside cards now pads to exact card inner width
- Replaced raw printf/erase_eol with card-aware functions
- Dot separator now uses `_CARD_INNER` for exact width

### Improvements
- Content is now properly padded inside cards (visible in how consistent the right borders look)
- Dot separators are consistent width in both columns
- Two commits visible now (repo has 2)
- Column balancing still works (1 blank row in Git card to match System)

### Remaining Issues

1. **Dot separator has trailing space before right border**: Line shows
   `│ ··············································· │` — there's a space between the last dot
   and the `│`. The dots should fill exactly to the card_print padding width.
   Root cause: `card_dots` prints `_CARD_INNER` dots, but the card content area is
   `_CARD_INNER` wide, so the dots fill it exactly. The space comes from the `│` + space
   padding on each side (col+2 to col+width-2). Let me verify: card starts at col 3,
   width 53, so inner content is col 5 to col 54 (50 chars). _CARD_INNER = 53-4 = 49.
   The dots are 49 chars. The `│` is at col 55. Col 5+49 = col 54. Col 55 is `│`. 
   That's... correct? But the capture shows a space. Might be that `card_print` adds
   padding after the dots.

2. **Session card right border still has huge whitespace**: The session names are short
   but the card is full width. This is correct behavior but looks sparse.

3. **Large gap between Sessions card and footer**: ~10 empty rows. Need to either:
   - Move footer closer to content
   - Add more content
   - Make the footer not fixed-to-bottom

4. **The 3-char gap between two-column cards**: `╮   ╭` — 3 spaces. Could be 1 space
   for a tighter look, or use a vertical line connector.

### Quality Assessment
- Card alignment: 8/10 — much better, borders consistent
- Content padding: 8/10 — card_print works well, dot separator has minor gap
- Overall layout: 7/10 — gap between content and footer is the main issue
- Visual cohesion: 8/10 — consistent card style throughout
