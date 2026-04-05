#!/usr/bin/env bash
# tmux-claude-overlay: Widget library
# High-level, composable UI components. Source after overlay.sh.
# Designed so overlays need minimal code to look great.

# ============================================================
# Text utilities
# ============================================================

# Truncate text to max visible width, adding ellipsis if needed.
# Usage: truncate_text "text" <max_width>
truncate_text() {
    local text="$1" max="$2"
    local stripped
    stripped=$(strip_ansi "$text")
    if [[ ${#stripped} -le $max ]]; then
        echo "$text"
    else
        echo "${stripped:0:$((max - 1))}…"
    fi
}

# Pad text to exact visible width (right-pad with spaces).
# Usage: pad_text "text" <width>
pad_text() {
    local text="$1" width="$2"
    local vlen
    vlen=$(visible_len "$text")
    local pad=$((width - vlen))
    if [[ $pad -gt 0 ]]; then
        printf '%s%*s' "$text" "$pad" ''
    else
        echo "$text"
    fi
}

# Shorten a path: /Users/foo/bar/baz → ~/bar/baz
shorten_path() {
    local path="$1" max="${2:-40}"
    path="${path/#$HOME/~}"
    if [[ ${#path} -le $max ]]; then
        echo "$path"
    else
        # Show ~/…/last_two_components
        local base
        base=$(basename "$path")
        local parent
        parent=$(basename "$(dirname "$path")")
        echo "~/…/${parent}/${base}"
    fi
}

# ============================================================
# Banner — big title at the top
# ============================================================

# Usage: widget_banner "Title" ["Subtitle"]
widget_banner() {
    local title="$1" subtitle="${2:-}"
    local cols=$SCREEN_INNER_COLS

    layout_spacer
    cursor_to "$_LAYOUT_CURSOR_ROW" "$_LAYOUT_CURSOR_COL"

    # Title with gradient if truecolor available
    if has_truecolor && [[ -n "${THEME_HEX_PRIMARY:-}" ]] && [[ -n "${THEME_HEX_SECONDARY:-}" ]]; then
        local pad=$(( (cols - ${#title}) / 2 ))
        [[ $pad -lt 0 ]] && pad=0
        printf '%*s' "$pad" ''
        printf '%s' "${BOLD}"
        gradient_text "$title" "${THEME_HEX_PRIMARY}" "${THEME_HEX_SECONDARY}"
    else
        draw_centered "${BOLD}${C_PRIMARY}${title}${RST}" "$cols"
    fi
    layout_advance 1

    if [[ -n "$subtitle" ]]; then
        cursor_to "$_LAYOUT_CURSOR_ROW" "$_LAYOUT_CURSOR_COL"
        draw_centered "${C_MUTED}${subtitle}${RST}" "$cols"
        layout_advance 1
    fi
    layout_spacer
}

# ============================================================
# Card — titled bordered box with content
# ============================================================

# Begin a card. Call widget_card_end when done.
# Usage: widget_card_begin "Title" [width]
# Content is rendered between begin/end using layout_* functions.
_CARD_ROW=0
_CARD_COL=0
_CARD_WIDTH=0
_CARD_START_ROW=0

widget_card_begin() {
    local title="$1"
    local width="${2:-$SCREEN_INNER_COLS}"

    _CARD_START_ROW=$_LAYOUT_CURSOR_ROW
    _CARD_COL=$_LAYOUT_CURSOR_COL
    _CARD_WIDTH=$width

    # Draw top border with title
    cursor_to "$_LAYOUT_CURSOR_ROW" "$_CARD_COL"
    local inner=$((width - 2))
    local title_display
    title_display=$(truncate_text "$title" $((inner - 4)))
    local title_len=${#title_display}
    local remaining=$((inner - title_len - 4))
    [[ $remaining -lt 0 ]] && remaining=0

    printf '%s%s%s %s%s%s%s %s' \
        "$THEME_BORDER_ACTIVE" "$_BOX_TL" "$_BOX_H" \
        "${BOLD}${C_PRIMARY}" "$title_display" "$RST" \
        "$THEME_BORDER_ACTIVE" "$_BOX_H"
    local i
    for ((i=0; i<remaining; i++)); do printf '%s' "$_BOX_H"; done
    printf '%s%s' "$_BOX_TR" "$RST"

    layout_advance 1

    # Indent content inside card
    _LAYOUT_CURSOR_COL=$((_CARD_COL + 2))
}

widget_card_end() {
    _LAYOUT_CURSOR_COL=$_CARD_COL
    local width=$_CARD_WIDTH

    # Draw side borders for all content rows
    local row
    for ((row=_CARD_START_ROW + 1; row < _LAYOUT_CURSOR_ROW; row++)); do
        cursor_to "$row" "$_CARD_COL"
        printf '%s%s%s' "$THEME_BORDER_ACTIVE" "$_BOX_V" "$RST"
        cursor_to "$row" $((_CARD_COL + width - 1))
        printf '%s%s%s' "$THEME_BORDER_ACTIVE" "$_BOX_V" "$RST"
    done

    # Bottom border
    cursor_to "$_LAYOUT_CURSOR_ROW" "$_CARD_COL"
    local inner=$((width - 2))
    printf '%s%s' "$THEME_BORDER_ACTIVE" "$_BOX_BL"
    local i
    for ((i=0; i<inner; i++)); do printf '%s' "$_BOX_H"; done
    printf '%s%s' "$_BOX_BR" "$RST"

    layout_advance 1
    _LAYOUT_CURSOR_COL=$((LAYOUT_PAD_LEFT + 1))
}

# Shorthand: a card with key-value pairs inside.
# Usage: widget_info_card "Title" "key1" "val1" "key2" "val2" ...
widget_info_card() {
    local title="$1"; shift
    widget_card_begin "$title"

    while [[ $# -ge 2 ]]; do
        local key="$1" val="$2"; shift 2
        local color="${C_TEXT}"
        # Auto-color special values
        case "$val" in
            clean|ok|success|passing) color="$C_SUCCESS" ;;
            dirty|warning|*)
                if [[ "$val" == *"dirty"* || "$val" == *"changed"* ]]; then
                    color="$C_WARNING"
                fi
                ;;
        esac
        cursor_to "$_LAYOUT_CURSOR_ROW" "$_LAYOUT_CURSOR_COL"
        printf '%s%-14s%s %s%s%s' "$C_MUTED" "$key" "$RST" "$color" "$val" "$RST"
        erase_eol
        layout_advance 1
    done

    widget_card_end
}

# ============================================================
# Stat row — horizontal row of labeled values
# ============================================================

# Usage: widget_stat_row "Label1" "Value1" "Label2" "Value2" ...
widget_stat_row() {
    local cols=$SCREEN_INNER_COLS
    local count=0
    local args=("$@")
    local total=$((${#args[@]} / 2))

    # Calculate column width
    local col_w=$((cols / total))
    [[ $col_w -gt 30 ]] && col_w=30

    cursor_to "$_LAYOUT_CURSOR_ROW" "$_LAYOUT_CURSOR_COL"

    local i=0
    while [[ $i -lt ${#args[@]} ]]; do
        local label="${args[$i]}"
        local value="${args[$((i+1))]}"
        local start_col=$((_LAYOUT_CURSOR_COL + (count * col_w)))
        cursor_to "$_LAYOUT_CURSOR_ROW" "$start_col"
        printf '%s%s%s' "$C_MUTED" "$label" "$RST"
        cursor_to "$((_LAYOUT_CURSOR_ROW + 1))" "$start_col"
        printf '%s%s%s%s' "$BOLD" "$C_TEXT" "$value" "$RST"
        count=$((count + 1))
        i=$((i + 2))
    done
    layout_advance 3
}

# ============================================================
# Badge / pill — colored inline label
# ============================================================

# Usage: widget_badge "text" <ok|warn|error|info|muted> [--inline]
widget_badge() {
    local text="$1" style="${2:-info}" inline="${3:-}"
    local fg bg
    case "$style" in
        ok|success|clean)
            fg="$FG_BLACK"; bg="$C_SUCCESS" ;;
        warn|warning|dirty)
            fg="$FG_BLACK"; bg="$C_WARNING" ;;
        error|fail)
            fg="$FG_WHITE"; bg="$C_ERROR" ;;
        info)
            fg="$FG_BLACK"; bg="$C_PRIMARY" ;;
        muted|*)
            fg="$C_TEXT"; bg="$C_MUTED" ;;
    esac
    # Use reverse video for the pill effect
    printf '%s%s %s %s' "${REVERSE}${bg}" "$fg" "$text" "$RST"
    [[ "$inline" != "--inline" ]] && layout_advance 1
}

# ============================================================
# Labeled status line
# ============================================================

# Usage: widget_status_line "Label" "status_text" <ok|warn|error|info>
widget_status_line() {
    local label="$1" text="$2" status="${3:-info}"
    cursor_to "$_LAYOUT_CURSOR_ROW" "$_LAYOUT_CURSOR_COL"
    printf '%s%-14s%s ' "$C_MUTED" "$label" "$RST"
    draw_status "$status" "$text"
    erase_eol
    layout_advance 1
}

# ============================================================
# Table — simple columnar data
# ============================================================

# Usage: widget_table_header "Col1" "Col2" "Col3" ...
# Then:  widget_table_row "val1" "val2" "val3" ...
_TABLE_COL_WIDTHS=()
_TABLE_NUM_COLS=0

widget_table_begin() {
    _TABLE_COL_WIDTHS=()
    _TABLE_NUM_COLS=$#
    local total_w=$SCREEN_INNER_COLS
    local per_col=$((total_w / $#))
    local i
    for ((i=0; i<$#; i++)); do
        _TABLE_COL_WIDTHS[$i]=$per_col
    done

    # Header
    cursor_to "$_LAYOUT_CURSOR_ROW" "$_LAYOUT_CURSOR_COL"
    local col=0
    for header in "$@"; do
        local x=$((_LAYOUT_CURSOR_COL + col * per_col))
        cursor_to "$_LAYOUT_CURSOR_ROW" "$x"
        printf '%s%s%s' "${BOLD}${C_MUTED}" "$header" "$RST"
        col=$((col + 1))
    done
    layout_advance 1

    # Separator
    cursor_to "$_LAYOUT_CURSOR_ROW" "$_LAYOUT_CURSOR_COL"
    local i
    for ((i=0; i<total_w - 4; i++)); do
        printf '%s─%s' "$THEME_BORDER" "$RST"
    done
    layout_advance 1
}

widget_table_row() {
    local per_col=${_TABLE_COL_WIDTHS[0]}
    cursor_to "$_LAYOUT_CURSOR_ROW" "$_LAYOUT_CURSOR_COL"
    local col=0
    for val in "$@"; do
        local x=$((_LAYOUT_CURSOR_COL + col * per_col))
        cursor_to "$_LAYOUT_CURSOR_ROW" "$x"
        local truncated
        truncated=$(truncate_text "$val" $((per_col - 2)))
        printf '%s%s%s' "$C_TEXT" "$truncated" "$RST"
        col=$((col + 1))
    done
    layout_advance 1
}

# ============================================================
# List — formatted items with icons
# ============================================================

# Usage: widget_list_item "icon" "text" [color]
widget_list_item() {
    local icon="$1" text="$2" color="${3:-$C_TEXT}"
    cursor_to "$_LAYOUT_CURSOR_ROW" "$_LAYOUT_CURSOR_COL"
    printf '  %s%s%s %s%s%s' "$C_ACCENT" "$icon" "$RST" "$color" "$text" "$RST"
    erase_eol
    layout_advance 1
}

# ============================================================
# Sparkline — inline mini chart
# ============================================================

# Usage: widget_sparkline "label" val1 val2 val3 ... [--max N]
# Values are 0-100 (or auto-scaled).
_SPARK_CHARS=("▁" "▂" "▃" "▄" "▅" "▆" "▇" "█")

widget_sparkline() {
    local label="$1"; shift
    local max_val=0
    local values=()

    for arg in "$@"; do
        if [[ "$arg" == "--max" ]]; then
            shift; max_val="$1"; shift; continue
        fi
        values[${#values[@]}]="$arg"
    done

    # Find max if not specified
    if [[ $max_val -eq 0 ]]; then
        for v in "${values[@]}"; do
            [[ $v -gt $max_val ]] && max_val=$v
        done
    fi
    [[ $max_val -eq 0 ]] && max_val=1

    cursor_to "$_LAYOUT_CURSOR_ROW" "$_LAYOUT_CURSOR_COL"
    printf '%s%-14s%s ' "$C_MUTED" "$label" "$RST"

    for v in "${values[@]}"; do
        local idx=$(( v * 7 / max_val ))
        [[ $idx -gt 7 ]] && idx=7
        [[ $idx -lt 0 ]] && idx=0
        printf '%s%s%s' "$C_PRIMARY" "${_SPARK_CHARS[$idx]}" "$RST"
    done
    erase_eol
    layout_advance 1
}

# ============================================================
# Separator — subtle line between items
# ============================================================

widget_separator() {
    local width="${1:-$SCREEN_INNER_COLS}"
    cursor_to "$_LAYOUT_CURSOR_ROW" "$_LAYOUT_CURSOR_COL"
    local i
    for ((i=0; i<width - 4; i++)); do
        printf '%s·%s' "$THEME_BORDER" "$RST"
    done
    layout_advance 1
}

# ============================================================
# Empty state
# ============================================================

widget_empty() {
    local message="${1:-No data}"
    local icon="${2:-∅}"
    layout_spacer
    cursor_to "$_LAYOUT_CURSOR_ROW" "$_LAYOUT_CURSOR_COL"
    draw_centered "${C_MUTED}${icon}  ${message}${RST}" "$SCREEN_INNER_COLS"
    layout_advance 1
    layout_spacer
}

# ============================================================
# Commit list — formatted git log
# ============================================================

# Usage: widget_commit_list [count] [dir]
widget_commit_list() {
    local count="${1:-5}" dir="${2:-}"
    local log
    log=$(git_log_oneline "$count" "$dir")

    if [[ -z "$log" ]]; then
        widget_empty "No commits"
        return
    fi

    local max_msg_width=$((SCREEN_INNER_COLS - 16))

    while IFS= read -r line; do
        local hash msg
        hash=$(echo "$line" | awk '{print $1}')
        msg=$(echo "$line" | cut -d' ' -f2-)
        msg=$(truncate_text "$msg" "$max_msg_width")

        cursor_to "$_LAYOUT_CURSOR_ROW" "$_LAYOUT_CURSOR_COL"
        printf '  %s%s%s %s%s%s' \
            "${BOLD}${C_ACCENT}" "$hash" "$RST" \
            "$C_MUTED" "$msg" "$RST"
        erase_eol
        layout_advance 1
    done <<< "$log"
}

# ============================================================
# Quick overlay — build a complete overlay in one call
# ============================================================

# Usage: quick_overlay "Title" <<'LAYOUT'
#   card "Section Name"
#     kv "Key" "Value"
#     kv "Key2" "Value2"
#   end
#   spacer
#   card "Another Section"
#     status "Build" "passing" ok
#     commits 5
#   end
# LAYOUT
#
# This is a declarative DSL parsed at runtime.

quick_overlay() {
    local title="$1"

    overlay_init "$title"

    local line
    while IFS= read -r line; do
        # Strip leading whitespace
        line=$(echo "$line" | sed 's/^[[:space:]]*//')
        [[ -z "$line" ]] && continue

        local cmd
        cmd=$(echo "$line" | awk '{print $1}')
        local rest
        rest=$(echo "$line" | sed 's/^[^ ]* *//')

        case "$cmd" in
            card)     widget_card_begin "$rest" ;;
            end)      widget_card_end ;;
            kv)
                local key val
                key=$(echo "$rest" | cut -d'"' -f2)
                val=$(echo "$rest" | cut -d'"' -f4)
                cursor_to "$_LAYOUT_CURSOR_ROW" "$_LAYOUT_CURSOR_COL"
                printf '%s%-14s%s %s%s%s' "$C_MUTED" "$key" "$RST" "$C_TEXT" "$val" "$RST"
                erase_eol
                layout_advance 1
                ;;
            status)
                local label text stype
                label=$(echo "$rest" | awk '{print $1}')
                text=$(echo "$rest" | awk '{print $2}')
                stype=$(echo "$rest" | awk '{print $3}')
                widget_status_line "$label" "$text" "$stype"
                ;;
            commits)  widget_commit_list "$rest" ;;
            spacer)   layout_spacer ;;
            banner)   widget_banner "$rest" ;;
            separator) widget_separator ;;
            *)        layout_print "$line" ;;
        esac
    done

    local hints
    hints=$(input_hint_string)
    layout_footer "$hints" "theme: ${OVERLAY_THEME}"

    input_bind "q" "input_stop" "uit"
    input_bind "escape" "input_stop" ""
    input_loop
}
