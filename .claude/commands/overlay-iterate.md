# Iterate on an Overlay's Visual Design

Run a screenshot-based iteration loop to improve an overlay's appearance.

**Arguments:** `$ARGUMENTS` — `<name> [--theme <theme>]`

## Instructions

Perform multiple rounds of visual iteration on the overlay:

### For each iteration round:

1. **Launch** the overlay in a detached tmux session:
   ```bash
   tmux new-session -d -s _overlay_iter -x 110 -y 40 \
     "OVERLAY_THEME=<theme> OVERLAY_ROOT=/Users/arun/tmux-claude-overlay \
      bash /Users/arun/tmux-claude-overlay/overlays/<name>.sh 2>/tmp/overlay_iter_err.log; sleep 999"
   ```

2. **Wait** for render (sleep 3), then **capture**:
   ```bash
   tmux capture-pane -t _overlay_iter -p > /Users/arun/tmux-claude-overlay/screenshots/iterations/<name>_<NNN>.txt
   ```

3. **Read** the captured text and **analyze** for issues:
   - Are card borders aligned? Do right `│` borders line up?
   - Is content properly padded inside cards?
   - Is the footer positioned correctly (not overlapping cards)?
   - Are there overflow issues on small terminals?
   - Is the visual hierarchy clear?
   - Is information density good (no huge gaps)?

4. **Write notes** to `screenshots/iterations/<name>_<NNN>_notes.md` with:
   - What changed in this iteration
   - Issues found
   - Quality scores (layout, alignment, visual hierarchy, each out of 10)
   - What to fix next

5. **Kill** the test session: `tmux kill-session -t _overlay_iter`

6. **Fix** the identified issues in the overlay code.

7. **Repeat** from step 1.

### Stop when:
- All borders align correctly
- Content is properly padded
- Layout works at both 80x30 (narrow) and 110x40 (wide)
- No overflow/overlap issues
- Footer is positioned correctly
- Quality scores are 8+ across the board

### Important:
- Always use `card_kv`, `card_text`, `card_status`, `card_dots` inside cards (not raw printf + erase_eol)
- Collect data into variables BEFORE rendering to avoid subshell issues with pipes
- Test narrow mode too: use `-x 80 -y 30` for the tmux session
- Use `<<< "$var"` instead of `cmd | while` to avoid subshell variable scoping
