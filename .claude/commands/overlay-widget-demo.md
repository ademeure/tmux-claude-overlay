# Widget Demo Overlay

Create and launch a temporary overlay that demonstrates all available widgets.

**Arguments:** `$ARGUMENTS` — (none required)

## Instructions

Create a temporary overlay at `/Users/arun/tmux-claude-overlay/overlays/_widget_demo.sh` that showcases every widget in the framework:

### Required widgets to demonstrate:

1. **widget_banner** — "Widget Gallery" with subtitle
2. **widget_stat_row** — 4 example metrics
3. **widget_card_begin/end** — A card with:
   - `card_kv` — 3 key-value pairs
   - `card_status` — ok, warn, error statuses
   - `card_dots` — dashed separator
   - `card_text` — plain text line
4. **widget_info_card** — Quick card with auto key-value pairs
5. **widget_badge** — Badges: ok, warn, error, info, muted
6. **widget_table_begin/widget_table_row** — 3-column table with sample data
7. **widget_list_item** — 3 items with different icons (▸, ●, ◆)
8. **widget_sparkline** — A sparkline with sample values
9. **widget_progress** (draw_progress) — 3 progress bars at different levels
10. **widget_separator** — Subtle divider
11. **widget_empty** — Empty state placeholder
12. **widget_commit_list** — Git commit list (if in a git repo)

### After creating:

1. Make it executable
2. Launch it: `bin/overlay launch _widget_demo --theme catppuccin`
3. Take a screenshot for the user to review

### Key bindings to include:
- `t` — cycle themes
- `r` — refresh
- `q` — quit

Use responsive layout: put widgets in two columns on wide terminals.
