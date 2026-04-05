#!/usr/bin/env bash
# tmux-claude-overlay: Theme system
# Provides theme loading and switching. Themes set semantic color variables.
# Source this file after colors.sh.

# Directory where theme files live
OVERLAY_THEME_DIR="${OVERLAY_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}/config/themes"

# Current theme name
OVERLAY_THEME="${OVERLAY_THEME:-catppuccin}"

# --- Theme: Catppuccin Mocha (default) ---
_theme_catppuccin() {
    # Background
    THEME_BG=$(hex_bg "#1e1e2e")
    THEME_BG_SURFACE=$(hex_bg "#313244")
    THEME_BG_HIGHLIGHT=$(hex_bg "#45475a")

    # Foreground
    THEME_FG=$(hex_fg "#cdd6f4")
    THEME_FG_MUTED=$(hex_fg "#6c7086")
    THEME_FG_SUBTLE=$(hex_fg "#a6adc8")

    # Accents
    THEME_PRIMARY=$(hex_fg "#89b4fa")       # Blue
    THEME_SECONDARY=$(hex_fg "#cba6f7")     # Mauve
    THEME_ACCENT=$(hex_fg "#f9e2af")        # Yellow
    THEME_SUCCESS=$(hex_fg "#a6e3a1")       # Green
    THEME_WARNING=$(hex_fg "#fab387")       # Peach
    THEME_ERROR=$(hex_fg "#f38ba8")         # Red
    THEME_INFO=$(hex_fg "#89dceb")          # Sky
    THEME_BORDER=$(hex_fg "#585b70")        # Surface2
    THEME_BORDER_ACTIVE=$(hex_fg "#89b4fa") # Blue

    # Hex values (for gradients etc)
    THEME_HEX_PRIMARY="#89b4fa"
    THEME_HEX_SECONDARY="#cba6f7"
    THEME_HEX_ACCENT="#f9e2af"
    THEME_HEX_SUCCESS="#a6e3a1"
    THEME_HEX_ERROR="#f38ba8"
    THEME_HEX_BG="#1e1e2e"
}

# --- Theme: Tokyo Night ---
_theme_tokyonight() {
    THEME_BG=$(hex_bg "#1a1b26")
    THEME_BG_SURFACE=$(hex_bg "#24283b")
    THEME_BG_HIGHLIGHT=$(hex_bg "#292e42")

    THEME_FG=$(hex_fg "#c0caf5")
    THEME_FG_MUTED=$(hex_fg "#565f89")
    THEME_FG_SUBTLE=$(hex_fg "#a9b1d6")

    THEME_PRIMARY=$(hex_fg "#7aa2f7")
    THEME_SECONDARY=$(hex_fg "#bb9af7")
    THEME_ACCENT=$(hex_fg "#e0af68")
    THEME_SUCCESS=$(hex_fg "#9ece6a")
    THEME_WARNING=$(hex_fg "#ff9e64")
    THEME_ERROR=$(hex_fg "#f7768e")
    THEME_INFO=$(hex_fg "#7dcfff")
    THEME_BORDER=$(hex_fg "#3b4261")
    THEME_BORDER_ACTIVE=$(hex_fg "#7aa2f7")

    THEME_HEX_PRIMARY="#7aa2f7"
    THEME_HEX_SECONDARY="#bb9af7"
    THEME_HEX_ACCENT="#e0af68"
    THEME_HEX_SUCCESS="#9ece6a"
    THEME_HEX_ERROR="#f7768e"
    THEME_HEX_BG="#1a1b26"
}

# --- Theme: Dracula ---
_theme_dracula() {
    THEME_BG=$(hex_bg "#282a36")
    THEME_BG_SURFACE=$(hex_bg "#343746")
    THEME_BG_HIGHLIGHT=$(hex_bg "#44475a")

    THEME_FG=$(hex_fg "#f8f8f2")
    THEME_FG_MUTED=$(hex_fg "#6272a4")
    THEME_FG_SUBTLE=$(hex_fg "#bfbfbf")

    THEME_PRIMARY=$(hex_fg "#bd93f9")
    THEME_SECONDARY=$(hex_fg "#ff79c6")
    THEME_ACCENT=$(hex_fg "#f1fa8c")
    THEME_SUCCESS=$(hex_fg "#50fa7b")
    THEME_WARNING=$(hex_fg "#ffb86c")
    THEME_ERROR=$(hex_fg "#ff5555")
    THEME_INFO=$(hex_fg "#8be9fd")
    THEME_BORDER=$(hex_fg "#6272a4")
    THEME_BORDER_ACTIVE=$(hex_fg "#bd93f9")

    THEME_HEX_PRIMARY="#bd93f9"
    THEME_HEX_SECONDARY="#ff79c6"
    THEME_HEX_ACCENT="#f1fa8c"
    THEME_HEX_SUCCESS="#50fa7b"
    THEME_HEX_ERROR="#ff5555"
    THEME_HEX_BG="#282a36"
}

# --- Theme: Nord ---
_theme_nord() {
    THEME_BG=$(hex_bg "#2e3440")
    THEME_BG_SURFACE=$(hex_bg "#3b4252")
    THEME_BG_HIGHLIGHT=$(hex_bg "#434c5e")

    THEME_FG=$(hex_fg "#eceff4")
    THEME_FG_MUTED=$(hex_fg "#4c566a")
    THEME_FG_SUBTLE=$(hex_fg "#d8dee9")

    THEME_PRIMARY=$(hex_fg "#88c0d0")
    THEME_SECONDARY=$(hex_fg "#b48ead")
    THEME_ACCENT=$(hex_fg "#ebcb8b")
    THEME_SUCCESS=$(hex_fg "#a3be8c")
    THEME_WARNING=$(hex_fg "#d08770")
    THEME_ERROR=$(hex_fg "#bf616a")
    THEME_INFO=$(hex_fg "#81a1c1")
    THEME_BORDER=$(hex_fg "#4c566a")
    THEME_BORDER_ACTIVE=$(hex_fg "#88c0d0")

    THEME_HEX_PRIMARY="#88c0d0"
    THEME_HEX_SECONDARY="#b48ead"
    THEME_HEX_ACCENT="#ebcb8b"
    THEME_HEX_SUCCESS="#a3be8c"
    THEME_HEX_ERROR="#bf616a"
    THEME_HEX_BG="#2e3440"
}

# --- Theme: Minimal (low-color, works on any terminal) ---
_theme_minimal() {
    THEME_BG=""
    THEME_BG_SURFACE=""
    THEME_BG_HIGHLIGHT="$REVERSE"

    THEME_FG="$FG_WHITE"
    THEME_FG_MUTED="$DIM$FG_WHITE"
    THEME_FG_SUBTLE="$FG_WHITE"

    THEME_PRIMARY="$FG_BRIGHT_CYAN"
    THEME_SECONDARY="$FG_BRIGHT_MAGENTA"
    THEME_ACCENT="$FG_BRIGHT_YELLOW"
    THEME_SUCCESS="$FG_BRIGHT_GREEN"
    THEME_WARNING="$FG_BRIGHT_YELLOW"
    THEME_ERROR="$FG_BRIGHT_RED"
    THEME_INFO="$FG_BRIGHT_BLUE"
    THEME_BORDER="$FG_BRIGHT_BLACK"
    THEME_BORDER_ACTIVE="$FG_BRIGHT_CYAN"

    THEME_HEX_PRIMARY=""
    THEME_HEX_SECONDARY=""
    THEME_HEX_ACCENT=""
    THEME_HEX_SUCCESS=""
    THEME_HEX_ERROR=""
    THEME_HEX_BG=""
}

# --- Apply theme to semantic colors ---
_apply_theme() {
    C_PRIMARY="$THEME_PRIMARY"
    C_SECONDARY="$THEME_SECONDARY"
    C_ACCENT="$THEME_ACCENT"
    C_SUCCESS="$THEME_SUCCESS"
    C_WARNING="$THEME_WARNING"
    C_ERROR="$THEME_ERROR"
    C_MUTED="$THEME_FG_MUTED"
    C_TEXT="$THEME_FG"
    C_HEADING="${BOLD}${THEME_PRIMARY}"
    C_BORDER="$THEME_BORDER"
    C_KEY_HINT="$THEME_FG_MUTED"

    C_BG_PRIMARY="$THEME_BG"
    C_BG_SURFACE="$THEME_BG_SURFACE"
    C_BG_HIGHLIGHT="$THEME_BG_HIGHLIGHT"
}

# --- Public API ---

# Load and apply a theme by name
# Usage: theme_load "catppuccin"
theme_load() {
    local name="${1:-$OVERLAY_THEME}"
    OVERLAY_THEME="$name"

    if declare -f "_theme_${name}" > /dev/null 2>&1; then
        "_theme_${name}"
    elif [[ -f "${OVERLAY_THEME_DIR}/${name}.sh" ]]; then
        # shellcheck disable=SC1090
        source "${OVERLAY_THEME_DIR}/${name}.sh"
    else
        echo "Warning: Unknown theme '${name}', falling back to catppuccin" >&2
        _theme_catppuccin
    fi

    _apply_theme
}

# List available themes
theme_list() {
    echo "catppuccin tokyonight dracula nord minimal"
    # Also list custom theme files
    if [[ -d "$OVERLAY_THEME_DIR" ]]; then
        for f in "$OVERLAY_THEME_DIR"/*.sh; do
            [[ -f "$f" ]] && basename "$f" .sh
        done
    fi
}

# Initialize default theme
theme_load "$OVERLAY_THEME"
