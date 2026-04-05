## Iteration 003 — Tighter layout, smarter footer (catppuccin, 110x40)

### Changes Made
- Reduced column gap from 3 chars to 1 char
- Footer now draws 1 row below content instead of fixed to screen bottom
- Dot separator replaced with `╌` dashed line (subtler, more professional)

### Assessment

- **Column gap**: 9/10 — 1 char gap is tight and clean. The `╮ ╭` between cards
  looks natural and saves horizontal space.
- **Footer position**: 9/10 — no more massive empty gap. Footer hugs the content.
  Only 1 blank row separates Sessions card from the footer separator line.
- **Dashed separator**: 9/10 — `╌╌╌` looks much better than `···`. It reads as a
  visual divider without being as heavy as `───`.
- **Content alignment**: 8/10 — content is padded properly inside cards. The right
  `│` border is consistently positioned.
- **Column balancing**: 9/10 — Git card has 1 blank row at bottom to match System
  card height. Both close at the same row.

### Remaining Minor Issues

1. **Dashed line has trailing space**: `╌╌╌╌╌ │` — there's still a 1-char gap between
   the last `╌` and the right `│` border. This is because `_CARD_INNER` = width - 4
   (2 for `│ ` on each side), but the content col starts at `_CARD_COL + 2` which is
   after `│` and one space. So content area = width - 4 = 48. But the right `│` is at
   col `_CARD_COL + width - 1`. Content ends at col `_CARD_COL + 2 + 48 = _CARD_COL + 50`.
   Right `│` at `_CARD_COL + 52`. Gap of 2 chars. That's the `space + │` on the right side.
   Actually this is correct! The card format is: `│ content │` with 1 space padding on
   each side of the content.

2. **Session card has unused horizontal space**: Full-width card with short session names.
   Could use a table format: `name | windows | status`

3. **Session "✦" attached marker could be brighter/more visible**

### Quality Scores
- Layout: 9/10
- Alignment: 9/10
- Visual hierarchy: 8/10
- Information density: 7/10
- Overall: 8.5/10
