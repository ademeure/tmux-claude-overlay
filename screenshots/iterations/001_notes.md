## Iteration 001 — Baseline (catppuccin, 110x40)

### Bugs / Alignment Issues

1. **Right border of left card misaligned**: The `│` on the right side of the Git card
   appears at col ~51, but the content inside (e.g., "◐ 1 changed") doesn't fill to
   the border consistently. There are trailing spaces before `│`. Same for right card.

2. **Card content not right-padded to border**: Inside cards, content ends wherever it
   ends, leaving irregular whitespace before the right `│`. Should pad to exact width.

3. **Dot separators inconsistent width**: The `···` line inside Git card and System card
   should span exactly to the card inner width. Currently looks visually ok but the dots
   inside left card vs right card may differ.

4. **Git card has 2 empty padding rows**: After the single commit, there are 2 blank
   rows before `╰`. This is the column-balancing code padding the shorter column to
   match the taller one — correct behavior, but blank rows look odd. Could fill with
   subtle content or use a different visual treatment.

5. **Session card right border**: The `│` on the right of Sessions card appears far from
   the session name content. The card is full width (~106 cols) but session names are
   short, leaving huge whitespace.

6. **Footer separator line**: The `──` separator before the footer spans the full width
   which is good, but there's a large gap (~10 empty rows) between the Sessions card
   bottom and the footer separator. This gap is the background color area.

7. **Stat row alignment**: The 4 stat columns (Branch, Sessions, Panes, Load) use equal
   widths but the values have very different lengths. "main" vs "23" vs "1" vs "5.27..."
   This is fine but could be more visually balanced.

8. **Banner centering**: "Terminal Dashboard" and the datetime subtitle are centered,
   which looks good. No issue here.

### Visual Quality Assessment

- Overall layout: 7/10 — two-column is good, hierarchy is clear
- Card borders: 6/10 — rounded corners work, but content-to-border padding is uneven
- Color/theming: 8/10 — catppuccin colors are good (can't fully judge from plain text)
- Information density: 6/10 — large whitespace gaps, could show more data
- Footer: 7/10 — key hints are clear, theme name on right is nice
- Interactivity: 8/10 — key bindings work well

### Priority Fixes

1. Pad card content to exact inner width (so right `│` aligns perfectly)
2. Fix the gap between cards and footer (either show more data or shrink footer position)
3. Make empty padding rows in balanced columns look intentional (subtle pattern or line)
