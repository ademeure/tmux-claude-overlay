#!/usr/bin/env bash
# Description: Demo dashboard — showcases the overlay framework

OVERLAY_ROOT="${OVERLAY_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
source "${OVERLAY_ROOT}/lib/overlay.sh"

[[ -n "${OVERLAY_STYLE:-}" ]] && draw_set_style "$OVERLAY_STYLE"
bus_init

# ============================================================
# Render
# ============================================================
render() {
    [[ -n "$C_BG_PRIMARY" ]] && fill_background || screen_clear
    layout_init

    widget_banner "Terminal Dashboard" "$(sys_datetime)"

    # Stat row
    widget_stat_row \
        "Branch"   "$(git_branch)" \
        "Sessions" "$(tmux_session_count)" \
        "Panes"    "$(tmux_pane_count)" \
        "Load"     "$(sys_load)"

    # Gather data upfront (avoid subshell issues)
    local _git_dirty=0; git_is_dirty && _git_dirty=1
    local _dirty_count; _dirty_count=$(git_dirty_count)
    local _last_commit; _last_commit=$(git_last_commit_time)
    local _git_log; _git_log=$(git_log_oneline 5)
    local _stash_count; _stash_count=$(git_stash_count)
    local _ahead_behind; _ahead_behind=$(git_ahead_behind)
    local _pane_path; _pane_path=$(shorten_path "$(tmux_pane_path)" 36)
    local _hostname; _hostname=$(sys_hostname)
    local _uptime; _uptime=$(sys_uptime)
    local _disk; _disk=$(sys_disk_usage)
    local _pane_info; _pane_info=$(tmux_list_panes_detail)
    local _sess_data; _sess_data=$(tmux list-sessions -F "#{session_name}|#{session_windows}|#{session_attached}" 2>/dev/null | head -6)

    local bp; bp=$(layout_breakpoint)

    if [[ "$bp" == "wide" ]]; then
        _render_wide
    else
        _render_narrow
    fi

    # Footer needs 2 rows (separator + bar). Cards need 2 rows (top + bottom border).
    # Only render sessions if we have room for card + at least 1 content row + footer.
    local footer_rows=2
    local rows_left=$((SCREEN_ROWS - _LAYOUT_CURSOR_ROW - footer_rows))

    if [[ $rows_left -ge 4 ]]; then
        layout_spacer
        local max_content_row=$((SCREEN_ROWS - footer_rows - 2))
        widget_card_begin "Sessions"
        if [[ -n "$_sess_data" ]]; then
            while IFS='|' read -r sess wins att; do
                [[ $_LAYOUT_CURSOR_ROW -ge $max_content_row ]] && break
                local marker=""
                [[ "$att" == "1" ]] && marker=" ✦"
                local line
                line=$(printf '%s%-26s%s %s%s win%s%s' \
                    "$C_SECONDARY" "$sess" "$RST" \
                    "$C_MUTED" "$wins" "$C_SUCCESS" "$marker")
                cursor_to "$_LAYOUT_CURSOR_ROW" "$_LAYOUT_CURSOR_COL"
                card_print "$line"
                layout_advance 1
            done <<< "$_sess_data"
        fi
        widget_card_end
    fi

    layout_footer "$(input_hint_string)" "$OVERLAY_THEME"
}

# ============================================================
# Two-column layout (wide terminals)
# ============================================================
_render_wide() {
    local gap=1
    local half=$(( (SCREEN_INNER_COLS - gap) / 2 ))
    local right_half=$((SCREEN_INNER_COLS - half - gap))
    local save_row=$_LAYOUT_CURSOR_ROW
    local left_col=$_LAYOUT_CURSOR_COL
    local right_col=$((_LAYOUT_CURSOR_COL + half + gap))

    # ── Left: Git ──
    widget_card_begin "Git" "$half"

    if [[ $_git_dirty -eq 1 ]]; then
        card_status "Status" "${_dirty_count} changed" "warn"
    else
        card_status "Status" "clean" "ok"
    fi
    card_kv "Last commit" "$_last_commit"
    card_kv "Remote" "$_ahead_behind" "$C_PRIMARY"
    [[ "$_stash_count" != "0" ]] && card_kv "Stashes" "$_stash_count" "$C_ACCENT"

    card_dots

    if [[ -n "$_git_log" ]]; then
        while IFS= read -r line; do
            local hash msg
            hash=$(echo "$line" | awk '{print $1}')
            msg=$(echo "$line" | cut -d' ' -f2-)
            msg=$(truncate_text "$msg" $((_CARD_INNER - 10)))
            local cline
            cline=$(printf '%s%s%s %s%s%s' \
                "${BOLD}${C_ACCENT}" "$hash" "$RST" \
                "$C_MUTED" "$msg" "$RST")
            cursor_to "$_LAYOUT_CURSOR_ROW" "$_LAYOUT_CURSOR_COL"
            card_print "$cline"
            layout_advance 1
        done <<< "$_git_log"
    fi

    # Save left state before closing
    local left_content_end=$_LAYOUT_CURSOR_ROW
    local left_card_start=$_CARD_START_ROW
    local left_card_col=$_CARD_COL
    local left_card_w=$_CARD_WIDTH

    # ── Right: System ──
    _LAYOUT_CURSOR_ROW=$save_row
    _LAYOUT_CURSOR_COL=$right_col

    widget_card_begin "System" "$right_half"

    card_kv "Directory" "$_pane_path" "$C_PRIMARY"
    card_kv "Hostname" "$_hostname"
    card_kv "Uptime" "$_uptime"
    card_kv "Disk" "$_disk"

    card_dots

    card_text "Active Panes" "${BOLD}${C_MUTED}"
    if [[ -n "$_pane_info" ]]; then
        while IFS= read -r line; do
            card_text "$line"
        done <<< "$_pane_info"
    fi

    local right_content_end=$_LAYOUT_CURSOR_ROW

    # Balance columns: pad the shorter one
    local target_end=$left_content_end
    [[ $right_content_end -gt $target_end ]] && target_end=$right_content_end

    # Pad right column
    while [[ $_LAYOUT_CURSOR_ROW -lt $target_end ]]; do
        cursor_to "$_LAYOUT_CURSOR_ROW" "$_LAYOUT_CURSOR_COL"
        card_print ""
        layout_advance 1
    done
    widget_card_end
    local right_end=$_LAYOUT_CURSOR_ROW

    # Close left card, padded to match
    _CARD_START_ROW=$left_card_start
    _CARD_COL=$left_card_col
    _CARD_WIDTH=$left_card_w
    _CARD_INNER=$((_CARD_WIDTH - 4))
    _LAYOUT_CURSOR_ROW=$target_end
    _LAYOUT_CURSOR_COL=$left_col

    # Pad left column blank rows
    local r
    for ((r=left_content_end; r<target_end; r++)); do
        cursor_to "$r" $((_CARD_COL + 2))
        card_print ""
    done

    widget_card_end
    local left_end=$_LAYOUT_CURSOR_ROW

    [[ $left_end -gt $right_end ]] && _LAYOUT_CURSOR_ROW=$left_end || _LAYOUT_CURSOR_ROW=$right_end
    _LAYOUT_CURSOR_COL=$((LAYOUT_PAD_LEFT + 1))
}

# ============================================================
# Single-column layout (narrow terminals)
# ============================================================
_render_narrow() {
    widget_card_begin "Git"
    if [[ $_git_dirty -eq 1 ]]; then
        card_status "Status" "${_dirty_count} changed" "warn"
    else
        card_status "Status" "clean" "ok"
    fi
    card_kv "Last commit" "$_last_commit"
    card_dots
    if [[ -n "$_git_log" ]]; then
        local _count=0
        while IFS= read -r line; do
            [[ $_count -ge 3 ]] && break
            local hash msg
            hash=$(echo "$line" | awk '{print $1}')
            msg=$(echo "$line" | cut -d' ' -f2-)
            msg=$(truncate_text "$msg" $((_CARD_INNER - 10)))
            local cline
            cline=$(printf '%s%s%s %s%s%s' \
                "${BOLD}${C_ACCENT}" "$hash" "$RST" \
                "$C_MUTED" "$msg" "$RST")
            cursor_to "$_LAYOUT_CURSOR_ROW" "$_LAYOUT_CURSOR_COL"
            card_print "$cline"
            layout_advance 1
            _count=$((_count + 1))
        done <<< "$_git_log"
    fi
    widget_card_end

    layout_spacer

    widget_card_begin "System"
    card_kv "Directory" "$_pane_path" "$C_PRIMARY"
    card_kv "Uptime" "$_uptime"
    card_kv "Load" "$(sys_load)"
    widget_card_end
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
    local _log; _log=$(git_log_graph 20)
    if [[ -n "$_log" ]]; then
        while IFS= read -r line; do
            card_text "  $line"
        done <<< "$_log"
    fi
    widget_card_end
    layout_footer "Press any key to return..."
    read -rsn1; data_cache_clear; render
}

view_sessions() {
    [[ -n "$C_BG_PRIMARY" ]] && fill_background || screen_clear
    layout_init
    widget_banner "Tmux Sessions"
    layout_spacer
    local _all; _all=$(tmux list-sessions -F "#{session_name}" 2>/dev/null)
    if [[ -n "$_all" ]]; then
        while IFS= read -r sess; do
            widget_card_begin "$sess"
            local _wins; _wins=$(tmux list-windows -t "$sess" -F "#{window_index}: #{window_name} (#{window_panes} panes)" 2>/dev/null)
            if [[ -n "$_wins" ]]; then
                while IFS= read -r win; do
                    card_text "$win"
                done <<< "$_wins"
            fi
            widget_card_end
        done <<< "$_all"
    fi
    layout_footer "Press any key to return..."
    read -rsn1; data_cache_clear; render
}

# ============================================================
# Keys
# ============================================================
do_refresh() { data_cache_clear; render; }
do_quit()    { bus_emit_dismiss "user_quit"; input_stop; }

do_theme_cycle() {
    local themes="catppuccin tokyonight dracula nord minimal"
    local i=0 ci=0
    for t in $themes; do [[ "$t" == "$OVERLAY_THEME" ]] && ci=$i; i=$((i+1)); done
    local total=$i ni=$(( (ci + 1) % total ))
    i=0; for t in $themes; do [[ $i -eq $ni ]] && OVERLAY_THEME="$t"; i=$((i+1)); done
    theme_load "$OVERLAY_THEME"; data_cache_clear; render
}

input_bind "r" "do_refresh"      "efresh"
input_bind "g" "view_git_log"    "it log"
input_bind "s" "view_sessions"   "essions"
input_bind "t" "do_theme_cycle"  "heme"
input_bind "?" "input_show_help" " help"
input_bind "q" "do_quit"         "uit"
input_bind "escape" "do_quit"    ""

overlay_start "Terminal Dashboard" "render"
