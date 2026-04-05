#!/usr/bin/env bash
# tmux-claude-overlay: Layout engine
# Screen detection, grid system, section management, responsive layout.
# Source after colors.sh, theme.sh, drawing.sh.

# ============================================================
# Screen dimensions
# ============================================================

# Current terminal dimensions (updated by layout_init or layout_refresh)
SCREEN_ROWS=0
SCREEN_COLS=0
SCREEN_INNER_ROWS=0   # Rows minus padding
SCREEN_INNER_COLS=0   # Cols minus padding

# Padding (configurable)
LAYOUT_PAD_TOP=1
LAYOUT_PAD_BOTTOM=1
LAYOUT_PAD_LEFT=2
LAYOUT_PAD_RIGHT=2

# Content area tracking
_LAYOUT_CURSOR_ROW=1
_LAYOUT_CURSOR_COL=1

# Initialize/refresh screen dimensions
layout_init() {
    SCREEN_ROWS=$(tput lines 2>/dev/null || echo 24)
    SCREEN_COLS=$(tput cols  2>/dev/null || echo 80)
    SCREEN_INNER_ROWS=$((SCREEN_ROWS - LAYOUT_PAD_TOP - LAYOUT_PAD_BOTTOM))
    SCREEN_INNER_COLS=$((SCREEN_COLS - LAYOUT_PAD_LEFT - LAYOUT_PAD_RIGHT))
    _LAYOUT_CURSOR_ROW=$((1 + LAYOUT_PAD_TOP))
    _LAYOUT_CURSOR_COL=$((1 + LAYOUT_PAD_LEFT))
}

layout_refresh() { layout_init; }

# ============================================================
# Content cursor
# ============================================================

# Get current content row
layout_row() { echo "$_LAYOUT_CURSOR_ROW"; }

# Advance the content cursor by N rows
layout_advance() {
    local n="${1:-1}"
    _LAYOUT_CURSOR_ROW=$((_LAYOUT_CURSOR_ROW + n))
}

# Set the content cursor to a specific row
layout_set_row() {
    _LAYOUT_CURSOR_ROW="$1"
}

# Move cursor to current layout position
layout_cursor() {
    cursor_to "$_LAYOUT_CURSOR_ROW" "$_LAYOUT_CURSOR_COL"
}

# ============================================================
# Section helper
# ============================================================

# Start a new section with a divider.
# Automatically positions it at the current layout cursor and advances.
# Usage: layout_section "Title" [color]
layout_section() {
    local title="$1" color="${2:-$C_HEADING}"
    layout_cursor
    draw_divider "$title" "$SCREEN_INNER_COLS" "$color"
    layout_advance 1
}

# Print a blank line (spacer) at current position
layout_spacer() {
    layout_advance "${1:-1}"
}

# Print text at current layout position and advance
# Usage: layout_print "text" [color]
layout_print() {
    local text="$1" color="${2:-$C_TEXT}"
    cursor_to "$_LAYOUT_CURSOR_ROW" "$_LAYOUT_CURSOR_COL"
    printf '%s%s%s' "$color" "$text" "$RST"
    erase_eol
    layout_advance 1
}

# Print a key-value pair at current position and advance
# Usage: layout_kv "Label" "Value" [label_color] [value_color]
layout_kv() {
    cursor_to "$_LAYOUT_CURSOR_ROW" "$_LAYOUT_CURSOR_COL"
    draw_kv "$@"
    layout_advance 1
}

# ============================================================
# Grid / column system
# ============================================================

# Calculate column widths for a given number of columns.
# Usage: layout_col_width <num_columns> [gap]
# Returns the width of each column.
layout_col_width() {
    local num_cols="$1" gap="${2:-2}"
    local total_gap=$(( (num_cols - 1) * gap ))
    echo $(( (SCREEN_INNER_COLS - total_gap) / num_cols ))
}

# Get the starting column (1-based) for a given column index.
# Usage: layout_col_start <col_index_0based> <num_columns> [gap]
layout_col_start() {
    local col_idx="$1" num_cols="$2" gap="${3:-2}"
    local col_w
    col_w=$(layout_col_width "$num_cols" "$gap")
    echo $(( LAYOUT_PAD_LEFT + 1 + col_idx * (col_w + gap) ))
}

# ============================================================
# Responsive breakpoints
# ============================================================

# Returns "narrow", "medium", or "wide" based on terminal width
layout_breakpoint() {
    if (( SCREEN_COLS < 60 )); then
        echo "narrow"
    elif (( SCREEN_COLS < 100 )); then
        echo "medium"
    else
        echo "wide"
    fi
}

# Returns 1 if screen is at least the given width
layout_min_width() {
    (( SCREEN_COLS >= $1 ))
}

layout_min_height() {
    (( SCREEN_ROWS >= $1 ))
}

# ============================================================
# Footer bar
# ============================================================

# Draw a footer bar at the bottom of the screen.
# Usage: layout_footer "left text" ["right text"]
layout_footer() {
    local left="$1" right="${2:-}"
    local row=$((SCREEN_ROWS - LAYOUT_PAD_BOTTOM))

    cursor_to "$row" 1
    printf '%s%s' "$C_BG_SURFACE" "$C_BORDER"
    printf '%*s' "$SCREEN_COLS" ''  # Fill with bg
    cursor_to "$row" $((1 + LAYOUT_PAD_LEFT))
    printf '%s%s%s' "$C_KEY_HINT" "$left" "$RST"

    if [[ -n "$right" ]]; then
        local right_len
        right_len=$(visible_len "$right")
        cursor_to "$row" $((SCREEN_COLS - LAYOUT_PAD_RIGHT - right_len))
        printf '%s%s%s' "$C_MUTED" "$right" "$RST"
    fi
}

# ============================================================
# Header bar
# ============================================================

# Draw a header bar at the top of the screen.
# Usage: layout_header "Title" ["right text"]
layout_header() {
    local title="$1" right="${2:-}"

    cursor_to 1 1
    printf '%s' "$C_BG_SURFACE"
    printf '%*s' "$SCREEN_COLS" ''  # Fill with bg
    cursor_to 1 $((1 + LAYOUT_PAD_LEFT))
    printf '%s%s%s%s' "$C_BG_SURFACE" "${BOLD}${C_PRIMARY}" "$title" "$RST"

    if [[ -n "$right" ]]; then
        local right_len
        right_len=$(visible_len "$right")
        cursor_to 1 $((SCREEN_COLS - LAYOUT_PAD_RIGHT - right_len))
        printf '%s%s%s%s' "$C_BG_SURFACE" "$C_MUTED" "$right" "$RST"
    fi

    # Set content start below header
    _LAYOUT_CURSOR_ROW=$((2 + LAYOUT_PAD_TOP))
}

# ============================================================
# WINCH (resize) handler
# ============================================================

# Register a function to call on terminal resize.
# Usage: layout_on_resize "my_redraw_function"
layout_on_resize() {
    local callback="$1"
    # shellcheck disable=SC2064
    trap "layout_refresh; $callback" WINCH
}

# Initialize on source
layout_init
