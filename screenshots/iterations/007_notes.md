## Iteration 007 — Multi-size robustness fixes

### Changes Made
1. Right column now uses `right_half = SCREEN_INNER_COLS - half - gap` (fills all space)
2. Footer skips separator line when tight on vertical space (avoids overwriting card borders)
3. Sessions card only renders if 4+ rows available (card borders + 1 content + footer)

### Results

| Size    | Mode   | Result |
|---------|--------|--------|
| 80x24   | medium | FIXED — System card `╰` border intact, footer bar only (no separator), sessions skipped |
| 100x30  | wide   | OK — two columns, 5 sessions, separator + footer |
| 110x40  | wide   | OK — two columns, right col 1 char wider, 6 sessions, separator + footer |

### Quality Scores
- 80x24: 9/10 — graceful degradation, all borders intact
- 100x30: 9/10 — clean two-column layout
- 110x40: 9/10 — balanced, right column fills available space
- Overall: 9/10
