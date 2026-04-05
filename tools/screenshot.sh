#!/usr/bin/env bash
# tmux-claude-overlay: Screenshot automation
# Captures overlay visuals via tmux capture-pane and macOS screencapture.
# Designed to let Claude (or humans) iterate on UI/UX by seeing results.
#
# Usage:
#   ./tools/screenshot.sh capture-text [target_pane] [output_file]
#   ./tools/screenshot.sh capture-image [output_file]
#   ./tools/screenshot.sh preview <overlay_script> [--theme <name>] [--width <w>] [--height <h>]
#   ./tools/screenshot.sh compare <file_a> <file_b>
#   ./tools/screenshot.sh gallery

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SCREENSHOT_DIR="${REPO_ROOT}/screenshots"
mkdir -p "$SCREENSHOT_DIR"

# ============================================================
# Text capture (tmux capture-pane)
# ============================================================
# Captures the current pane content including ANSI color codes.
# This is fast and doesn't require GUI access.

cmd_capture_text() {
    local target="${1:-}"
    local output="${2:-${SCREENSHOT_DIR}/capture_$(date +%Y%m%d_%H%M%S).txt}"

    local tmux_args=(-p -e)  # -p prints to stdout, -e includes escape sequences
    [[ -n "$target" ]] && tmux_args+=(-t "$target")

    tmux capture-pane "${tmux_args[@]}" > "$output"
    echo "Text capture saved: $output"
    echo "  Size: $(wc -c < "$output") bytes, $(wc -l < "$output") lines"
}

# ============================================================
# Image capture (macOS screencapture)
# ============================================================
# Takes an actual screenshot of the terminal window.
# Requires GUI access (won't work in headless environments).

cmd_capture_image() {
    local output="${1:-${SCREENSHOT_DIR}/screenshot_$(date +%Y%m%d_%H%M%S).png}"

    if ! command -v screencapture &>/dev/null; then
        echo "Error: screencapture not found (macOS only)" >&2
        return 1
    fi

    # Capture the frontmost window (-l with window ID, or -w for interactive)
    # Using a small delay to let the overlay render
    screencapture -o -x -l "$(get_terminal_window_id)" "$output" 2>/dev/null || {
        # Fallback: capture the frontmost window
        screencapture -o -x -w "$output" 2>/dev/null || {
            echo "Error: screencapture failed" >&2
            return 1
        }
    }

    echo "Image saved: $output"
    if command -v sips &>/dev/null; then
        local dims
        dims=$(sips -g pixelHeight -g pixelWidth "$output" 2>/dev/null | tail -2 | awk '{print $2}' | paste -sd'x')
        echo "  Dimensions: $dims"
    fi
}

# Get the iTerm2/Terminal window ID for targeted screencapture
get_terminal_window_id() {
    # Try iTerm2 first via AppleScript
    osascript -e 'tell application "iTerm2" to id of front window' 2>/dev/null || \
    osascript -e 'tell application "Terminal" to id of front window' 2>/dev/null || \
    echo ""
}

# ============================================================
# Preview: launch overlay in a controlled pane, capture, teardown
# ============================================================
# This is the main tool for automated UI iteration.
# It launches an overlay script in a sized tmux pane, captures it,
# and tears down the pane — all without user interaction.

cmd_preview() {
    local overlay_script="$1"; shift
    local theme="catppuccin" width=80 height=24 delay=1 format="both"

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --theme)  theme="$2";  shift 2 ;;
            --width)  width="$2";  shift 2 ;;
            --height) height="$2"; shift 2 ;;
            --delay)  delay="$2";  shift 2 ;;
            --format) format="$2"; shift 2 ;; # text, image, both
            *)        shift ;;
        esac
    done

    local timestamp
    timestamp=$(date +%Y%m%d_%H%M%S)
    local base_name
    base_name=$(basename "$overlay_script" .sh)
    local prefix="${SCREENSHOT_DIR}/${base_name}_${theme}_${timestamp}"

    echo "Preview: ${base_name} (theme: ${theme}, ${width}x${height})"

    # Create a detached session with specific dimensions
    local session_name="_overlay_preview_$$"
    tmux new-session -d -s "$session_name" -x "$width" -y "$height" \
        "OVERLAY_THEME=${theme} bash '${overlay_script}'; sleep 999" 2>/dev/null

    # Wait for the overlay to render
    sleep "$delay"

    # Capture text
    if [[ "$format" == "text" || "$format" == "both" ]]; then
        local text_file="${prefix}.txt"
        tmux capture-pane -t "$session_name" -p -e > "$text_file"
        echo "  Text: $text_file ($(wc -l < "$text_file") lines)"
    fi

    # Capture ANSI-stripped text (for diffing)
    local plain_file="${prefix}_plain.txt"
    tmux capture-pane -t "$session_name" -p > "$plain_file"

    # Capture image if possible and requested
    if [[ "$format" == "image" || "$format" == "both" ]]; then
        local img_file="${prefix}.png"
        # We can't easily screenshot a detached session, but we can
        # attach it briefly in a popup for capture
        echo "  (Image capture requires visible window — use capture-image manually)"
    fi

    # Kill the preview session
    tmux kill-session -t "$session_name" 2>/dev/null

    echo "  Plain: $plain_file"
    echo "Done."
}

# ============================================================
# Interactive preview: launch overlay in a popup you can see
# ============================================================
# Opens the overlay in a tmux popup so you can see it live,
# and captures when you dismiss it.

cmd_interactive_preview() {
    local overlay_script="$1"; shift
    local theme="${1:-catppuccin}"
    local width="${2:-80%}"
    local height="${3:-80%}"

    local timestamp
    timestamp=$(date +%Y%m%d_%H%M%S)
    local base_name
    base_name=$(basename "$overlay_script" .sh)
    local text_file="${SCREENSHOT_DIR}/${base_name}_${theme}_${timestamp}.txt"

    echo "Launching interactive preview..."
    echo "  Press 'q' or Escape in the overlay to dismiss."

    # Capture the current pane ID so we know where we are
    local original_pane
    original_pane=$(tmux display-message -p '#D')

    # Launch the overlay
    tmux display-popup -w "$width" -h "$height" -E \
        "OVERLAY_THEME=${theme} bash '${overlay_script}'"

    echo "Preview closed."
    echo "  Capture: $text_file"
}

# ============================================================
# Compare two captures (text diff)
# ============================================================

cmd_compare() {
    local file_a="$1" file_b="$2"

    if ! command -v diff &>/dev/null; then
        echo "Error: diff not found" >&2
        return 1
    fi

    echo "Comparing:"
    echo "  A: $file_a"
    echo "  B: $file_b"
    echo ""

    # Strip ANSI codes for meaningful diff
    local tmp_a tmp_b
    tmp_a=$(mktemp)
    tmp_b=$(mktemp)
    sed 's/\x1b\[[0-9;]*[a-zA-Z]//g' "$file_a" > "$tmp_a"
    sed 's/\x1b\[[0-9;]*[a-zA-Z]//g' "$file_b" > "$tmp_b"

    diff --color=always -u "$tmp_a" "$tmp_b" || true
    rm -f "$tmp_a" "$tmp_b"
}

# ============================================================
# Gallery: list all captures
# ============================================================

cmd_gallery() {
    echo "Screenshots in: $SCREENSHOT_DIR"
    echo ""

    local count=0
    for f in "$SCREENSHOT_DIR"/*; do
        [[ -f "$f" ]] || continue
        local name
        name=$(basename "$f")
        local size
        size=$(wc -c < "$f" | tr -d ' ')
        local date
        date=$(stat -f '%Sm' -t '%Y-%m-%d %H:%M' "$f" 2>/dev/null || stat --format='%y' "$f" 2>/dev/null | cut -d. -f1)
        printf "  %-50s %8s bytes  %s\n" "$name" "$size" "$date"
        ((count++))
    done

    echo ""
    echo "Total: $count files"
}

# ============================================================
# Batch preview: render all themes for an overlay
# ============================================================

cmd_batch_themes() {
    local overlay_script="$1"
    local themes=(catppuccin tokyonight dracula nord minimal)

    echo "Batch preview: rendering all themes..."
    for theme in "${themes[@]}"; do
        cmd_preview "$overlay_script" --theme "$theme" --format text
    done
    echo ""
    echo "All themes rendered. Check: $SCREENSHOT_DIR/"
}

# ============================================================
# Main dispatch
# ============================================================

case "${1:-help}" in
    capture-text)         shift; cmd_capture_text "$@" ;;
    capture-image)        shift; cmd_capture_image "$@" ;;
    preview)              shift; cmd_preview "$@" ;;
    interactive-preview)  shift; cmd_interactive_preview "$@" ;;
    compare)              shift; cmd_compare "$@" ;;
    gallery)              shift; cmd_gallery "$@" ;;
    batch-themes)         shift; cmd_batch_themes "$@" ;;
    help|*)
        echo "tmux-claude-overlay screenshot tool"
        echo ""
        echo "Commands:"
        echo "  capture-text [pane] [output]     Capture pane content with ANSI codes"
        echo "  capture-image [output]           Screenshot terminal window (macOS)"
        echo "  preview <script> [options]       Render overlay in detached pane, capture"
        echo "    --theme <name>                   Theme to use (default: catppuccin)"
        echo "    --width <cols>                   Terminal width (default: 80)"
        echo "    --height <rows>                  Terminal height (default: 24)"
        echo "    --delay <secs>                   Wait before capture (default: 1)"
        echo "  interactive-preview <script>     Launch in popup, capture on dismiss"
        echo "  compare <file_a> <file_b>        Diff two text captures"
        echo "  gallery                          List all captures"
        echo "  batch-themes <script>            Render overlay in all themes"
        ;;
esac
