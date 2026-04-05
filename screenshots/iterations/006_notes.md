## Iteration 006 — Multi-size testing (catppuccin)

### Results by size

| Size    | Mode   | Issues |
|---------|--------|--------|
| 110x40  | wide   | OK — empty rows at bottom after footer (cosmetic) |
| 100x30  | wide   | OK — clean, sessions capped to 5 |
| 99x30   | medium | OK — single column, sessions capped to 1, dashes separator extends too far (see below) |
| 120x45  | wide   | OK — empty rows at bottom after footer (cosmetic) |
| 80x24   | medium | BUG — footer renders INSIDE System card (before ╰), sessions card has no room |

### Bugs Found

1. **80x24: footer inside card** — System card opens but at 80x24 there's not enough
   vertical space. The footer separator + keybinds render inside the System card (between
   content and bottom border), same bug we fixed for Sessions card. The overflow protection
   only applies to the Sessions card, not to any card that might overflow.

2. **99x30: dashed separator misaligned** — In single-column mode with full-width cards,
   the `╌` line extends 1 char too far. The line is `_CARD_INNER` chars (72) but visually
   it extends past where other content ends, ending with `╌ │` rather than `╌╌│`. This is
   actually the same padding behavior as all content — the ╌ fills _CARD_INNER (72) and
   then there's 1 space + │. But it looks odd because dashes create an expectation of
   reaching the border.

3. **All wide modes: 1 unused column on right edge** — The two-column layout uses
   `half = (INNER - 1) / 2` which leaves 1 column unused when INNER is even.
   Fix: make right card `SCREEN_INNER_COLS - half - gap` wide.

### Priority Fixes
1. Fix 80x24: need global overflow protection, not just for sessions card
2. Fix right column width to fill all available space
3. Make card_dots connect to card border (remove the trailing space)
