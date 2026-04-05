#!/usr/bin/env bash
# Description: Demo dashboard — showcases the overlay framework

OVERLAY_ROOT="${OVERLAY_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
source "${OVERLAY_ROOT}/lib/overlay.sh"

[[ -n "${OVERLAY_STYLE:-}" ]] && draw_set_style "$OVERLAY_STYLE"
bus_init

# ============================================================
# Helper: render a key-value line at current position
# ============================================================
_kv() {
    local label="$1" value="$2" vcolor="${3:-$C_TEXT}"
    cursor_to "$_LAYOUT_CURSOR_ROW" "$_LAYOUT_CURSOR_COL"
    printf '%s%-14s%s %s%s%s' "$C_MUTED" "$label" "$RST" "$vcolor" "$value" "$RST"
    erase_eol
    layout_advance 1
}

# Dot separator inside a card
_dots() {
    local w="${1:-40}"
    cursor_to "$_LAYOUT_CURSOR_ROW" "$_LAYOUT_CURSOR_COL"
    printf '%s' "$THEME_BORDER"
    local i; for ((i=0; i<w; i++)); do printf '·'; done
    printf '%s' "$RST"
    layout_advance 1
}

# ============================================================
# Render
# ============================================================
render() {
    [[ -n "$C_BG_PRIMARY" ]] && fill_background || screen_clear
    layout_init

    # Banner
    widget_banner "Terminal Dashboard" "$(sys_datetime)"

    # Stat row
    widget_stat_row \
        "Branch"   "$(git_branch)" \
        "Sessions" "$(tmux_session_count)" \
        "Panes"    "$(tmux_pane_count)" \
        "Load"     "$(sys_load)"

    # Gather data upfront to avoid subshell issues
    local _git_dirty _dirty_count _last_commit _git_log _pane_path
    local _hostname _uptime _disk _pane_info _sess_data
    local _stash_count _ahead_behind

    _git_dirty=0; git_is_dirty && _git_dirty=1
    _dirty_count=$(git_dirty_count)
    _last_commit=$(git_last_commit_time)
    _git_log=$(git_log_oneline 5)
    _stash_count=$(git_stash_count)
    _ahead_behind=$(git_ahead_behind)
    _pane_path=$(tmux_pane_path)
    _pane_path=$(shorten_path "$_pane_path" 36)
    _hostname=$(sys_hostname)
    _uptime=$(sys_uptime)
    _disk=$(sys_disk_usage)
    _pane_info=$(tmux_list_panes_detail)
    _sess_data=$(tmux list-sessions -F "#{session_name}|#{session_windows}|#{session_attached}" 2>/dev/null | head -6)

    local bp
    bp=$(layout_breakpoint)

    if [[ "$bp" == "wide" ]]; then
        local half=$(( (SCREEN_INNER_COLS - 3) / 2 ))
        local save_row=$_LAYOUT_CURSOR_ROW
        local left_col=$_LAYOUT_CURSOR_COL
        local right_col=$((_LAYOUT_CURSOR_COL + half + 3))
        local dot_w=$((half - 6))

        # ── Left: Git ──
        widget_card_begin "Git" "$half"

        if [[ $_git_dirty -eq 1 ]]; then
            cursor_to "$_LAYOUT_CURSOR_ROW" "$_LAYOUT_CURSOR_COL"
            printf '%s%-14s%s ' "$C_MUTED" "Status" "$RST"
            draw_status "warn" "${_dirty_count} changed"
            erase_eol; layout_advance 1
        else
            cursor_to "$_LAYOUT_CURSOR_ROW" "$_LAYOUT_CURSOR_COL"
            printf '%s%-14s%s ' "$C_MUTED" "Status" "$RST"
            draw_status "ok" "clean"
            erase_eol; layout_advance 1
        fi

        _kv "Last commit" "$_last_commit"
        _kv "Remote" "$_ahead_behind" "$C_PRIMARY"
        [[ "$_stash_count" != "0" ]] && _kv "Stashes" "$_stash_count" "$C_ACCENT"

        _dots "$dot_w"

        if [[ -n "$_git_log" ]]; then
            while IFS= read -r line; do
                local hash msg
                hash=$(echo "$line" | awk '{print $1}')
                msg=$(echo "$line" | cut -d' ' -f2-)
                msg=$(truncate_text "$msg" $((half - 16)))
                cursor_to "$_LAYOUT_CURSOR_ROW" "$_LAYOUT_CURSOR_COL"
                printf '%s%s%s %s%s%s' \
                    "${BOLD}${C_ACCENT}" "$hash" "$RST" \
                    "$C_MUTED" "$msg" "$RST"
                erase_eol; layout_advance 1
            done <<< "$_git_log"
        fi

        # Save left content end row (before card_end draws bottom border)
        local left_content_end=$_LAYOUT_CURSOR_ROW

        # Don't close left card yet — measure right first

        # ── Right: System ──
        # Temporarily save left state and switch to right column
        local left_card_start=$_CARD_START_ROW
        local left_card_col=$_CARD_COL
        local left_card_w=$_CARD_WIDTH

        _LAYOUT_CURSOR_ROW=$save_row
        _LAYOUT_CURSOR_COL=$right_col

        widget_card_begin "System" "$half"

        _kv "Directory" "$_pane_path" "$C_PRIMARY"
        _kv "Hostname" "$_hostname"
        _kv "Uptime" "$_uptime"
        _kv "Disk" "$_disk"

        _dots "$dot_w"

        cursor_to "$_LAYOUT_CURSOR_ROW" "$_LAYOUT_CURSOR_COL"
        printf '%s%sActive Panes%s' "${BOLD}" "$C_MUTED" "$RST"
        erase_eol; layout_advance 1

        if [[ -n "$_pane_info" ]]; then
            while IFS= read -r line; do
                cursor_to "$_LAYOUT_CURSOR_ROW" "$_LAYOUT_CURSOR_COL"
                printf '%s%s%s' "$C_TEXT" "$line" "$RST"
                erase_eol; layout_advance 1
            done <<< "$_pane_info"
        fi

        local right_content_end=$_LAYOUT_CURSOR_ROW

        # Balance: pad the shorter column to match the taller one
        local target_end=$left_content_end
        [[ $right_content_end -gt $target_end ]] && target_end=$right_content_end

        # Pad right column
        while [[ $_LAYOUT_CURSOR_ROW -lt $target_end ]]; do
            layout_advance 1
        done
        widget_card_end
        local right_end=$_LAYOUT_CURSOR_ROW

        # Now close left card, padded to match
        _CARD_START_ROW=$left_card_start
        _CARD_COL=$left_card_col
        _CARD_WIDTH=$left_card_w
        _LAYOUT_CURSOR_ROW=$target_end
        _LAYOUT_CURSOR_COL=$left_col
        widget_card_end
        local left_end=$_LAYOUT_CURSOR_ROW

        [[ $left_end -gt $right_end ]] && _LAYOUT_CURSOR_ROW=$left_end || _LAYOUT_CURSOR_ROW=$right_end
        _LAYOUT_CURSOR_COL=$((LAYOUT_PAD_LEFT + 1))

    else
        # ── Single column ──
        widget_card_begin "Git"
        if [[ $_git_dirty -eq 1 ]]; then
            widget_status_line "Status" "${_dirty_count} changed" "warn"
        else
            widget_status_line "Status" "clean" "ok"
        fi
        _kv "Last commit" "$_last_commit"
        widget_commit_list 3
        widget_card_end

        layout_spacer

        widget_card_begin "System"
        _kv "Directory" "$_pane_path" "$C_PRIMARY"
        _kv "Uptime" "$_uptime"
        _kv "Load" "$(sys_load)"
        widget_card_end
    fi

    layout_spacer

    # ── Sessions card ──
    widget_card_begin "Sessions"
    if [[ -n "$_sess_data" ]]; then
        while IFS='|' read -r sess wins att; do
            local marker=""
            [[ "$att" == "1" ]] && marker=" ✦"
            cursor_to "$_LAYOUT_CURSOR_ROW" "$_LAYOUT_CURSOR_COL"
            printf '%s%-28s%s %s%s win%s%s' \
                "$C_SECONDARY" "$sess" "$RST" \
                "$C_MUTED" "$wins" "$C_SUCCESS" "$marker"
            erase_eol; layout_advance 1
        done <<< "$_sess_data"
    fi
    widget_card_end

    # Footer
    layout_footer "$(input_hint_string)" "$OVERLAY_THEME"
}

# ============================================================
# Subviews
# ============================================================
view_git_log() {
    [[ -n "$C_BG_PRIMARY" ]] && fill_background || screen_clear
    layout_init
    widget_banner "Git Log"
    layout_spacer
    widget_card_begin "Commit Graph (last 20)"
    local _log
    _log=$(git_log_graph 20)
    if [[ -n "$_log" ]]; then
        while IFS= read -r line; do
            cursor_to "$_LAYOUT_CURSOR_ROW" "$_LAYOUT_CURSOR_COL"
            printf '  %s%s' "$line" "$RST"
            erase_eol; layout_advance 1
        done <<< "$_log"
    fi
    widget_card_end
    layout_footer "Press any key to return..."
    read -rsn1
    data_cache_clear; render
}

view_sessions() {
    [[ -n "$C_BG_PRIMARY" ]] && fill_background || screen_clear
    layout_init
    widget_banner "Tmux Sessions"
    layout_spacer
    local _all
    _all=$(tmux list-sessions -F "#{session_name}" 2>/dev/null)
    if [[ -n "$_all" ]]; then
        while IFS= read -r sess; do
            widget_card_begin "$sess"
            local _wins
            _wins=$(tmux list-windows -t "$sess" -F "#{window_index}: #{window_name} (#{window_panes} panes)" 2>/dev/null)
            if [[ -n "$_wins" ]]; then
                while IFS= read -r win; do
                    cursor_to "$_LAYOUT_CURSOR_ROW" "$_LAYOUT_CURSOR_COL"
                    printf '%s%s%s' "$C_TEXT" "$win" "$RST"
                    erase_eol; layout_advance 1
                done <<< "$_wins"
            fi
            widget_card_end
        done <<< "$_all"
    fi
    layout_footer "Press any key to return..."
    read -rsn1
    data_cache_clear; render
}

# ============================================================
# Key bindings
# ============================================================
do_refresh() { data_cache_clear; render; }
do_quit()    { bus_emit_dismiss "user_quit"; input_stop; }

do_theme_cycle() {
    local themes="catppuccin tokyonight dracula nord minimal"
    local i=0 ci=0
    for t in $themes; do [[ "$t" == "$OVERLAY_THEME" ]] && ci=$i; i=$((i+1)); done
    local total=$i ni=$(( (ci + 1) % total ))
    i=0; for t in $themes; do [[ $i -eq $ni ]] && OVERLAY_THEME="$t"; i=$((i+1)); done
    theme_load "$OVERLAY_THEME"
    data_cache_clear; render
}

input_bind "r" "do_refresh"      "efresh"
input_bind "g" "view_git_log"    "it log"
input_bind "s" "view_sessions"   "essions"
input_bind "t" "do_theme_cycle"  "heme"
input_bind "?" "input_show_help" " help"
input_bind "q" "do_quit"         "uit"
input_bind "escape" "do_quit"    ""

overlay_start "Terminal Dashboard" "render"
