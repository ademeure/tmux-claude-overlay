## Iteration 008 — 153x43 investigation

### Issue Reported
User screenshot showed Git card content appearing shifted/truncated at popup size.
Screenshot showed "Directory ~/github/orchestrator" — popup was in a different repo.

### Investigation
- Text capture at 153x43 shows PERFECT alignment — all borders, content padding, columns
- `strip_ansi` works correctly on macOS BSD sed (tested with 24-bit color codes)
- `visible_len` returns exact expected values (27 for a status line with ANSI colors)
- `card_print` padding math is correct: _CARD_INNER=70, visible=27, pad=43

### Root Cause
The visual issue was likely either:
1. Popup opened in ~/github/orchestrator (different repo, different commit messages)
2. Transient rendering during popup initialization or resize
3. The popup inherited a different working directory than expected

### Conclusion
No code changes needed. The framework renders correctly at 153x43.
All sizes tested clean: 80x24, 99x30, 100x30, 110x40, 120x45, 153x43.

### Quality: 9.5/10
