#!/usr/bin/env bash
# tmux-claude-overlay: Color system
# Provides named colors, 24-bit support, and color utilities.
# Source this file — do not execute directly.

# Reset
RST=$'\033[0m'

# Attributes
BOLD=$'\033[1m'
DIM=$'\033[2m'
ITALIC=$'\033[3m'
UNDERLINE=$'\033[4m'
BLINK=$'\033[5m'
REVERSE=$'\033[7m'
HIDDEN=$'\033[8m'
STRIKE=$'\033[9m'

# --- 256-color helpers ---

# Usage: color256_fg <0-255>
color256_fg() { printf '\033[38;5;%dm' "$1"; }

# Usage: color256_bg <0-255>
color256_bg() { printf '\033[48;5;%dm' "$1"; }

# --- 24-bit / truecolor helpers ---

# Usage: rgb_fg <r> <g> <b>  (each 0-255)
rgb_fg() { printf '\033[38;2;%d;%d;%dm' "$1" "$2" "$3"; }

# Usage: rgb_bg <r> <g> <b>  (each 0-255)
rgb_bg() { printf '\033[48;2;%d;%d;%dm' "$1" "$2" "$3"; }

# Usage: hex_fg "#rrggbb" or "rrggbb"
hex_fg() {
    local hex="${1#\#}"
    printf '\033[38;2;%d;%d;%dm' \
        "0x${hex:0:2}" "0x${hex:2:2}" "0x${hex:4:2}"
}

# Usage: hex_bg "#rrggbb" or "rrggbb"
hex_bg() {
    local hex="${1#\#}"
    printf '\033[48;2;%d;%d;%dm' \
        "0x${hex:0:2}" "0x${hex:2:2}" "0x${hex:4:2}"
}

# --- Standard ANSI foreground ---
FG_BLACK=$'\033[30m'
FG_RED=$'\033[31m'
FG_GREEN=$'\033[32m'
FG_YELLOW=$'\033[33m'
FG_BLUE=$'\033[34m'
FG_MAGENTA=$'\033[35m'
FG_CYAN=$'\033[36m'
FG_WHITE=$'\033[37m'

# Bright foreground
FG_BRIGHT_BLACK=$'\033[90m'
FG_BRIGHT_RED=$'\033[91m'
FG_BRIGHT_GREEN=$'\033[92m'
FG_BRIGHT_YELLOW=$'\033[93m'
FG_BRIGHT_BLUE=$'\033[94m'
FG_BRIGHT_MAGENTA=$'\033[95m'
FG_BRIGHT_CYAN=$'\033[96m'
FG_BRIGHT_WHITE=$'\033[97m'

# --- Standard ANSI background ---
BG_BLACK=$'\033[40m'
BG_RED=$'\033[41m'
BG_GREEN=$'\033[42m'
BG_YELLOW=$'\033[43m'
BG_BLUE=$'\033[44m'
BG_MAGENTA=$'\033[45m'
BG_CYAN=$'\033[46m'
BG_WHITE=$'\033[47m'

# Bright background
BG_BRIGHT_BLACK=$'\033[100m'
BG_BRIGHT_RED=$'\033[101m'
BG_BRIGHT_GREEN=$'\033[102m'
BG_BRIGHT_YELLOW=$'\033[103m'
BG_BRIGHT_BLUE=$'\033[104m'
BG_BRIGHT_MAGENTA=$'\033[105m'
BG_BRIGHT_CYAN=$'\033[106m'
BG_BRIGHT_WHITE=$'\033[107m'

# --- Semantic colors (overridden by themes) ---
# These are defaults; themes override them.
C_PRIMARY="${FG_BRIGHT_CYAN}"
C_SECONDARY="${FG_BRIGHT_MAGENTA}"
C_ACCENT="${FG_BRIGHT_YELLOW}"
C_SUCCESS="${FG_BRIGHT_GREEN}"
C_WARNING="${FG_BRIGHT_YELLOW}"
C_ERROR="${FG_BRIGHT_RED}"
C_MUTED="${DIM}${FG_WHITE}"
C_TEXT="${FG_WHITE}"
C_HEADING="${BOLD}${FG_BRIGHT_CYAN}"
C_BORDER="${FG_BRIGHT_CYAN}"
C_KEY_HINT="${DIM}${FG_WHITE}"

# Background semantic colors
C_BG_PRIMARY=""       # Set by theme (empty = terminal default)
C_BG_SURFACE=""       # Slightly elevated surface
C_BG_HIGHLIGHT=""     # Highlighted/selected row

# --- Color detection ---

# Returns 0 if terminal supports truecolor
has_truecolor() {
    [[ "$COLORTERM" == "truecolor" || "$COLORTERM" == "24bit" ]] && return 0
    # iTerm2 and most modern terminals support it
    [[ -n "$ITERM_SESSION_ID" ]] && return 0
    return 1
}

# Returns 0 if terminal supports 256 colors
has_256color() {
    [[ "$TERM" == *"256color"* ]] && return 0
    has_truecolor && return 0
    return 1
}

# --- Gradient helper ---

# Usage: gradient_fg <start_r> <start_g> <start_b> <end_r> <end_g> <end_b> <step> <total_steps>
# Returns the interpolated color escape for a gradient at a given step.
gradient_fg() {
    local sr=$1 sg=$2 sb=$3 er=$4 eg=$5 eb=$6 step=$7 total=$8
    if (( total <= 1 )); then
        rgb_fg "$sr" "$sg" "$sb"
        return
    fi
    local r=$(( sr + (er - sr) * step / (total - 1) ))
    local g=$(( sg + (eg - sg) * step / (total - 1) ))
    local b=$(( sb + (eb - sb) * step / (total - 1) ))
    rgb_fg "$r" "$g" "$b"
}

# Convert hex pair to decimal (bash 3.2 compatible)
_hex2dec() { printf '%d' "0x$1"; }

# Usage: gradient_text "text" <start_hex> <end_hex>
# Prints text with per-character color gradient.
gradient_text() {
    local text="$1" start="${2#\#}" end="${3#\#}"
    local sr; sr=$(_hex2dec "${start:0:2}")
    local sg; sg=$(_hex2dec "${start:2:2}")
    local sb; sb=$(_hex2dec "${start:4:2}")
    local er; er=$(_hex2dec "${end:0:2}")
    local eg; eg=$(_hex2dec "${end:2:2}")
    local eb; eb=$(_hex2dec "${end:4:2}")
    local len=${#text}
    local i
    for ((i=0; i<len; i++)); do
        printf '%s%s' "$(gradient_fg $sr $sg $sb $er $eg $eb $i $len)" "${text:$i:1}"
    done
    printf '%s' "$RST"
}

# --- Strip ANSI codes (for length calculations) ---
strip_ansi() {
    # Remove all ANSI escape sequences
    sed 's/\x1b\[[0-9;]*[a-zA-Z]//g' <<< "$1"
}

# Visible length of a string (excluding ANSI codes)
visible_len() {
    local stripped
    stripped=$(strip_ansi "$1")
    echo ${#stripped}
}
