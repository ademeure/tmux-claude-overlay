# Create a New Overlay

Create a new tmux-claude-overlay using the framework.

**Arguments:** `$ARGUMENTS` — `<name> [description]`

## Instructions

1. Parse `$ARGUMENTS`: first word is the overlay name, rest is the description.

2. Check if `/Users/arun/tmux-claude-overlay/overlays/<name>.sh` already exists.

3. Create the overlay file using this template structure:

```bash
#!/usr/bin/env bash
# Description: <description>

OVERLAY_ROOT="${OVERLAY_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
source "${OVERLAY_ROOT}/lib/overlay.sh"

[[ -n "${OVERLAY_STYLE:-}" ]] && draw_set_style "$OVERLAY_STYLE"
bus_init

render() {
    [[ -n "$C_BG_PRIMARY" ]] && fill_background || screen_clear
    layout_init

    widget_banner "<Title>" "$(sys_datetime)"

    # Use card_kv, card_text, card_status, card_dots inside cards
    widget_card_begin "<Section>"
    card_kv "Label" "Value"
    widget_card_end

    layout_footer "$(input_hint_string)" "$OVERLAY_THEME"
}

do_refresh() { data_cache_clear; render; }
do_quit()    { bus_emit_dismiss "user_quit"; input_stop; }

input_bind "r" "do_refresh" "efresh"
input_bind "q" "do_quit"    "uit"
input_bind "escape" "do_quit" ""

overlay_start "<Title>" "render"
```

4. Customize the content based on the description. Available helpers:
   - **Data**: `git_branch`, `git_is_dirty`, `sys_load`, `tmux_session_name`, etc.
   - **Widgets**: `widget_banner`, `widget_card_begin/end`, `widget_stat_row`, `widget_badge`
   - **Card helpers**: `card_kv`, `card_text`, `card_status`, `card_dots` (properly padded)
   - **Layout**: `layout_breakpoint` returns "narrow"/"medium"/"wide" for responsive design
   - **Colors**: `$C_PRIMARY`, `$C_SECONDARY`, `$C_ACCENT`, `$C_SUCCESS`, `$C_WARNING`, `$C_ERROR`

5. Make executable: `chmod +x overlays/<name>.sh`

6. Test with: `bin/overlay launch <name>` or use `/overlay-iterate` to refine visually.
