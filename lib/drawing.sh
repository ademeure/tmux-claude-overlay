#!/usr/bin/env bash
# tmux-claude-overlay: Drawing primitives
# Box drawing, borders, lines, text alignment, padding.
# Source after colors.sh and theme.sh.

# ============================================================
# Box-drawing character sets
# ============================================================

# Rounded (default)
BOX_ROUND_TL="╭" BOX_ROUND_TR="╮" BOX_ROUND_BL="╰" BOX_ROUND_BR="╯"
BOX_ROUND_H="─" BOX_ROUND_V="│"
BOX_ROUND_T_LEFT="├" BOX_ROUND_T_RIGHT="┤" BOX_ROUND_T_DOWN="┬" BOX_ROUND_T_UP="┴"

# Sharp
BOX_SHARP_TL="┌" BOX_SHARP_TR="┐" BOX_SHARP_BL="└" BOX_SHARP_BR="┘"
BOX_SHARP_H="─" BOX_SHARP_V="│"

# Double
BOX_DOUBLE_TL="╔" BOX_DOUBLE_TR="╗" BOX_DOUBLE_BL="╚" BOX_DOUBLE_BR="╝"
BOX_DOUBLE_H="═" BOX_DOUBLE_V="║"

# Heavy
BOX_HEAVY_TL="┏" BOX_HEAVY_TR="┓" BOX_HEAVY_BL="┗" BOX_HEAVY_BR="┛"
BOX_HEAVY_H="━" BOX_HEAVY_V="┃"

# Block (for solid borders)
BOX_BLOCK_FULL="█" BOX_BLOCK_HALF="▌" BOX_BLOCK_QUARTER="░"
BOX_BLOCK_MEDIUM="▒" BOX_BLOCK_DARK="▓"

# Active box style (set by draw_set_style or defaults to round)
_BOX_TL="$BOX_ROUND_TL" _BOX_TR="$BOX_ROUND_TR"
_BOX_BL="$BOX_ROUND_BL" _BOX_BR="$BOX_ROUND_BR"
_BOX_H="$BOX_ROUND_H"   _BOX_V="$BOX_ROUND_V"

# Usage: draw_set_style <round|sharp|double|heavy>
draw_set_style() {
    local style="${1:-round}"
    case "$style" in
        round)
            _BOX_TL="$BOX_ROUND_TL"; _BOX_TR="$BOX_ROUND_TR"
            _BOX_BL="$BOX_ROUND_BL"; _BOX_BR="$BOX_ROUND_BR"
            _BOX_H="$BOX_ROUND_H";   _BOX_V="$BOX_ROUND_V" ;;
        sharp)
            _BOX_TL="$BOX_SHARP_TL"; _BOX_TR="$BOX_SHARP_TR"
            _BOX_BL="$BOX_SHARP_BL"; _BOX_BR="$BOX_SHARP_BR"
            _BOX_H="$BOX_SHARP_H";   _BOX_V="$BOX_SHARP_V" ;;
        double)
            _BOX_TL="$BOX_DOUBLE_TL"; _BOX_TR="$BOX_DOUBLE_TR"
            _BOX_BL="$BOX_DOUBLE_BL"; _BOX_BR="$BOX_DOUBLE_BR"
            _BOX_H="$BOX_DOUBLE_H";   _BOX_V="$BOX_DOUBLE_V" ;;
        heavy)
            _BOX_TL="$BOX_HEAVY_TL"; _BOX_TR="$BOX_HEAVY_TR"
            _BOX_BL="$BOX_HEAVY_BL"; _BOX_BR="$BOX_HEAVY_BR"
            _BOX_H="$BOX_HEAVY_H";   _BOX_V="$BOX_HEAVY_V" ;;
    esac
}

# ============================================================
# Cursor / screen control
# ============================================================

# Move cursor to row, col (1-based)
cursor_to()    { printf '\033[%d;%dH' "$1" "$2"; }
cursor_up()    { printf '\033[%dA' "${1:-1}"; }
cursor_down()  { printf '\033[%dB' "${1:-1}"; }
cursor_right() { printf '\033[%dC' "${1:-1}"; }
cursor_left()  { printf '\033[%dD' "${1:-1}"; }
cursor_hide()  { printf '\033[?25l'; }
cursor_show()  { printf '\033[?25h'; }
cursor_save()  { printf '\033[s'; }
cursor_restore() { printf '\033[u'; }

# Clear screen with current background color
screen_clear() { printf '\033[2J\033[H'; }

# Erase to end of line (fills with current bg)
erase_eol() { printf '\033[K'; }

# ============================================================
# Background fill
# ============================================================

# Fill the entire screen with the theme background color.
# Call this at the start of your overlay to get a solid background.
fill_background() {
    # Set background color and clear screen. The terminal's native clear
    # (\033[2J) fills with the current background color and always uses
    # the correct pane dimensions — no manual size detection needed.
    # This avoids the tput-in-popup bug where tput returns wrong sizes.
    printf '%s\033[2J\033[H' "${C_BG_PRIMARY}"
}

# ============================================================
# Horizontal lines / dividers
# ============================================================

# Usage: draw_hline [width] [char] [color]
draw_hline() {
    local width="${1:-$(tput cols)}" char="${2:-$_BOX_H}" color="${3:-$C_BORDER}"
    printf '%s' "$color"
    local i
    for ((i=0; i<width; i++)); do printf '%s' "$char"; done
    printf '%s\n' "$RST"
}

# Labeled divider: ── Label ──────────
# Usage: draw_divider "Label" [width] [color]
draw_divider() {
    local label="$1"
    local width="${2:-$(tput cols)}"
    local color="${3:-$C_HEADING}"
    local label_len
    label_len=$(visible_len "$label")
    local remaining=$((width - label_len - 4))  # 2 chars + space each side
    (( remaining < 0 )) && remaining=0

    printf '%s%s%s %s%s%s %s' \
        "$C_BORDER" "$_BOX_H" "$_BOX_H" \
        "$color" "$label" \
        "$C_BORDER" ""

    local i
    for ((i=0; i<remaining; i++)); do printf '%s' "$_BOX_H"; done
    printf '%s\n' "$RST"
}

# ============================================================
# Box drawing
# ============================================================

# Draw a box outline at a given position and size.
# Usage: draw_box <row> <col> <height> <width> [border_color]
draw_box() {
    local row=$1 col=$2 height=$3 width=$4
    local border_color="${5:-$C_BORDER}"
    local inner=$((width - 2))

    # Top border
    cursor_to "$row" "$col"
    printf '%s%s' "$border_color" "$_BOX_TL"
    local i
    for ((i=0; i<inner; i++)); do printf '%s' "$_BOX_H"; done
    printf '%s%s' "$_BOX_TR" "$RST"

    # Side borders
    for ((i=1; i<height-1; i++)); do
        cursor_to $((row + i)) "$col"
        printf '%s%s' "$border_color" "$_BOX_V"
        cursor_to $((row + i)) $((col + width - 1))
        printf '%s%s' "$_BOX_V" "$RST"
    done

    # Bottom border
    cursor_to $((row + height - 1)) "$col"
    printf '%s%s' "$border_color" "$_BOX_BL"
    for ((i=0; i<inner; i++)); do printf '%s' "$_BOX_H"; done
    printf '%s%s' "$_BOX_BR" "$RST"
}

# Draw a box with a title in the top border.
# Usage: draw_titled_box <row> <col> <height> <width> "Title" [border_color] [title_color]
draw_titled_box() {
    local row=$1 col=$2 height=$3 width=$4 title="$5"
    local border_color="${6:-$C_BORDER}" title_color="${7:-$C_HEADING}"
    local inner=$((width - 2))
    local title_len
    title_len=$(visible_len "$title")

    # Top border with title
    cursor_to "$row" "$col"
    printf '%s%s%s' "$border_color" "$_BOX_TL" "$_BOX_H"
    printf ' %s%s%s %s' "$title_color" "$title" "$RST" "$border_color"
    local used=$((title_len + 4))
    local remaining=$((inner - used))
    local i
    for ((i=0; i<remaining; i++)); do printf '%s' "$_BOX_H"; done
    printf '%s%s' "$_BOX_TR" "$RST"

    # Side borders with background fill
    for ((i=1; i<height-1; i++)); do
        cursor_to $((row + i)) "$col"
        printf '%s%s' "$border_color" "$_BOX_V"
        # Fill interior with background
        printf '%s' "$C_BG_SURFACE"
        printf '%*s' "$inner" ''
        printf '%s%s%s' "$RST" "$border_color" "$_BOX_V"
        printf '%s' "$RST"
    done

    # Bottom border
    cursor_to $((row + height - 1)) "$col"
    printf '%s%s' "$border_color" "$_BOX_BL"
    for ((i=0; i<inner; i++)); do printf '%s' "$_BOX_H"; done
    printf '%s%s' "$_BOX_BR" "$RST"
}

# ============================================================
# Text rendering
# ============================================================

# Print text at a specific position.
# Usage: draw_text <row> <col> "text" [color]
draw_text() {
    local row=$1 col=$2 text="$3" color="${4:-$C_TEXT}"
    cursor_to "$row" "$col"
    printf '%s%s%s' "$color" "$text" "$RST"
}

# Print text centered in a given width.
# Usage: draw_centered "text" [width] [color]
draw_centered() {
    local text="$1"
    local width="${2:-$(tput cols)}"
    local color="${3:-$C_TEXT}"
    local text_len
    text_len=$(visible_len "$text")
    local pad=$(( (width - text_len) / 2 ))
    (( pad < 0 )) && pad=0
    printf '%*s%s%s%s\n' "$pad" '' "$color" "$text" "$RST"
}

# Print text right-aligned in a given width.
# Usage: draw_right "text" [width] [color]
draw_right() {
    local text="$1"
    local width="${2:-$(tput cols)}"
    local color="${3:-$C_TEXT}"
    local text_len
    text_len=$(visible_len "$text")
    local pad=$((width - text_len))
    (( pad < 0 )) && pad=0
    printf '%*s%s%s%s' "$pad" '' "$color" "$text" "$RST"
}

# Key-value pair: "  Label:     Value"
# Usage: draw_kv "Label" "Value" [label_color] [value_color] [label_width]
draw_kv() {
    local label="$1" value="$2"
    local label_color="${3:-$C_MUTED}" value_color="${4:-$C_TEXT}"
    local label_width="${5:-16}"
    printf '  %s%-*s%s %s%s%s\n' \
        "$label_color" "$label_width" "$label" "$RST" \
        "$value_color" "$value" "$RST"
}

# ============================================================
# Progress / status indicators
# ============================================================

# Status dot with label
# Usage: draw_status "ok|warn|error|info" "label"
draw_status() {
    local status="$1" label="$2"
    case "$status" in
        ok|success|clean)  printf '%s● %s%s' "$C_SUCCESS" "$label" "$RST" ;;
        warn|warning|dirty) printf '%s◐ %s%s' "$C_WARNING" "$label" "$RST" ;;
        error|fail)        printf '%s✖ %s%s' "$C_ERROR" "$label" "$RST" ;;
        info)              printf '%s◆ %s%s' "$C_INFO" "$label" "$RST" ;;
        *)                 printf '%s○ %s%s' "$C_MUTED" "$label" "$RST" ;;
    esac
}

# Simple progress bar
# Usage: draw_progress <current> <total> [width] [filled_color] [empty_color]
draw_progress() {
    local current=$1 total=$2
    local width="${3:-20}"
    local filled_color="${4:-$C_SUCCESS}" empty_color="${5:-$C_MUTED}"

    local filled=0
    (( total > 0 )) && filled=$(( current * width / total ))
    local empty=$((width - filled))

    printf '%s' "$filled_color"
    local i
    for ((i=0; i<filled; i++)); do printf '█'; done
    printf '%s' "$empty_color"
    for ((i=0; i<empty; i++)); do printf '░'; done
    printf '%s' "$RST"
}

# Spinner frames (call in a loop with index)
SPINNER_FRAMES=("⠋" "⠙" "⠹" "⠸" "⠼" "⠴" "⠦" "⠧" "⠇" "⠏")
SPINNER_DOTS=("⣾" "⣽" "⣻" "⢿" "⡿" "⣟" "⣯" "⣷")
SPINNER_SIMPLE=("-" "\\" "|" "/")

# Usage: draw_spinner <frame_index> [color]
draw_spinner() {
    local idx=$(( $1 % ${#SPINNER_FRAMES[@]} ))
    local color="${2:-$C_PRIMARY}"
    printf '%s%s%s' "$color" "${SPINNER_FRAMES[$idx]}" "$RST"
}

# ============================================================
# Cleanup
# ============================================================

# Call this on exit to restore terminal state
draw_cleanup() {
    cursor_show
    printf '%s' "$RST"
}
