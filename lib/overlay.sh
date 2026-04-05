#!/usr/bin/env bash
# tmux-claude-overlay: Overlay framework loader
# Source this single file to get the entire framework.
# Usage in an overlay script:
#   #!/usr/bin/env bash
#   source "$(dirname "$0")/../lib/overlay.sh"
#   # ... your overlay code ...

# Determine OVERLAY_ROOT
export OVERLAY_ROOT="${OVERLAY_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"

# Source all framework libraries in order
source "${OVERLAY_ROOT}/lib/colors.sh"
source "${OVERLAY_ROOT}/lib/theme.sh"
source "${OVERLAY_ROOT}/lib/drawing.sh"
source "${OVERLAY_ROOT}/lib/layout.sh"
source "${OVERLAY_ROOT}/lib/data.sh"
source "${OVERLAY_ROOT}/lib/input.sh"
source "${OVERLAY_ROOT}/lib/widgets.sh"
source "${OVERLAY_ROOT}/lib/bus.sh"

# ============================================================
# Overlay lifecycle
# ============================================================

# Initialize an overlay: clear screen, fill background, hide cursor, set up cleanup.
# Usage: overlay_init ["Title"]
overlay_init() {
    local title="${1:-}"

    # Set up cleanup trap
    trap '_overlay_cleanup' EXIT INT TERM

    # Hide cursor
    cursor_hide

    # Detect screen size FIRST (must happen before fill_background,
    # because tput returns wrong values inside tmux popups)
    layout_init

    # Clear and fill background using correct dimensions
    if [[ -n "$C_BG_PRIMARY" ]]; then
        fill_background
    else
        screen_clear
    fi

    # Note: overlays handle their own header/banner in their render function.
    # overlay_init just sets up the terminal — no header drawn here.
}

# Cleanup handler — restores terminal state on exit
_overlay_cleanup() {
    cursor_show
    printf '%s' "$RST"
    screen_clear
}

# Render loop: call a render function, then enter input loop.
# The render function is also called on resize.
# Usage: overlay_run <render_function>
overlay_run() {
    local render_fn="$1"

    # Initial render
    "$render_fn"

    # Re-render on resize
    layout_on_resize "$render_fn"

    # Enter input loop
    input_loop
}

# Convenience: full overlay lifecycle.
# Usage: overlay_start "Title" <render_function>
overlay_start() {
    local title="$1" render_fn="$2"
    overlay_init "$title"
    overlay_run "$render_fn"
}

# ============================================================
# Overlay registration (for the launcher)
# ============================================================

# Overlays directory
OVERLAY_DIR="${OVERLAY_ROOT}/overlays"

# List available overlays
overlay_list() {
    if [[ -d "$OVERLAY_DIR" ]]; then
        for f in "$OVERLAY_DIR"/*.sh; do
            [[ -f "$f" ]] || continue
            local name
            name=$(basename "$f" .sh)
            # Try to extract description from first comment
            local desc
            desc=$(head -5 "$f" | grep '^# Description:' | sed 's/^# Description: *//')
            [[ -z "$desc" ]] && desc=$(head -5 "$f" | grep -v '^#!' | grep '^#' | head -1 | sed 's/^# *//')
            printf "  %-20s %s\n" "$name" "$desc"
        done
    fi
}

# Get path to an overlay by name
overlay_path() {
    local name="$1"
    local path="${OVERLAY_DIR}/${name}.sh"
    if [[ -f "$path" ]]; then
        echo "$path"
    else
        echo "Overlay not found: $name" >&2
        return 1
    fi
}
