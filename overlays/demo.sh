#!/usr/bin/env bash
# Description: Demo dashboard — showcases the overlay framework
# A demo overlay that displays session, git, and system info
# using the full framework (themes, layout, drawing, input).

OVERLAY_ROOT="${OVERLAY_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
source "${OVERLAY_ROOT}/lib/overlay.sh"

# Apply box style if set
[[ -n "${OVERLAY_STYLE:-}" ]] && draw_set_style "$OVERLAY_STYLE"

# ============================================================
# Render function — called on init and resize
# ============================================================

render() {
    # Clear and refill background
    if [[ -n "$C_BG_PRIMARY" ]]; then
        fill_background
    else
        screen_clear
    fi
    layout_init

    # Header
    layout_header "Terminal Dashboard" "$(sys_datetime)"

    # ── Session section ──
    layout_section "SESSION"
    layout_kv "Session:"     "$(tmux_session_name)" "$C_MUTED" "${BOLD}${C_TEXT}"
    layout_kv "Window:"      "$(tmux_window_name)"
    layout_kv "Panes:"       "$(tmux_pane_count)"
    layout_kv "Sessions:"    "$(tmux_session_count)"

    layout_spacer

    # ── Git section ──
    layout_section "GIT"
    layout_kv "Branch:" "$(git_branch)" "$C_MUTED" "${BOLD}${C_SECONDARY}"

    if git_is_dirty; then
        local count
        count=$(git_dirty_count)
        cursor_to "$(_LAYOUT_ROW=$_LAYOUT_CURSOR_ROW; echo $_LAYOUT_ROW)" "$_LAYOUT_CURSOR_COL"
        printf '  %s%-16s%s ' "$C_MUTED" "Status:" "$RST"
        draw_status "warn" "${count} changed files"
        echo ""
        layout_advance 1
    else
        cursor_to "$_LAYOUT_CURSOR_ROW" "$_LAYOUT_CURSOR_COL"
        printf '  %s%-16s%s ' "$C_MUTED" "Status:" "$RST"
        draw_status "ok" "clean"
        echo ""
        layout_advance 1
    fi

    layout_kv "Last commit:" "$(git_last_commit_time)"

    layout_spacer

    # Recent commits
    local commits
    commits=$(git_log_oneline 5)
    if [[ -n "$commits" ]]; then
        cursor_to "$_LAYOUT_CURSOR_ROW" "$_LAYOUT_CURSOR_COL"
        printf '  %sRecent commits:%s\n' "$C_MUTED" "$RST"
        layout_advance 1

        while IFS= read -r line; do
            local hash msg
            hash=$(echo "$line" | awk '{print $1}')
            msg=$(echo "$line" | cut -d' ' -f2-)
            cursor_to "$_LAYOUT_CURSOR_ROW" $((_LAYOUT_CURSOR_COL + 2))
            printf '%s%s%s %s%s%s\n' "$C_ACCENT" "$hash" "$RST" "$C_MUTED" "$msg" "$RST"
            layout_advance 1
        done <<< "$commits"
    fi

    layout_spacer

    # ── System section ──
    layout_section "SYSTEM"
    local pane_path
    pane_path=$(tmux_pane_path)
    layout_kv "Directory:" "${pane_path/#$HOME/\~}" "$C_MUTED" "$C_PRIMARY"
    layout_kv "Uptime:"    "$(sys_uptime)"
    layout_kv "Load:"      "$(sys_load)"
    layout_kv "Disk:"      "$(sys_disk_usage)"

    layout_spacer

    # ── Active panes ──
    layout_section "ACTIVE PANES"
    local pane_info
    pane_info=$(tmux_list_panes_detail)
    if [[ -n "$pane_info" ]]; then
        while IFS= read -r line; do
            layout_print "  $line" "$C_TEXT"
        done <<< "$pane_info"
    fi

    # Footer
    local hints
    hints=$(input_hint_string)
    layout_footer "$hints" "theme: ${OVERLAY_THEME}"
}

# ============================================================
# Key bindings
# ============================================================

do_refresh() {
    data_cache_clear
    render
}

do_git_log() {
    if [[ -n "$C_BG_PRIMARY" ]]; then
        fill_background
    else
        screen_clear
    fi
    layout_init
    layout_header "Git Log" "$(sys_datetime)"
    layout_section "COMMIT GRAPH (last 20)"
    layout_spacer

    local log
    log=$(git_log_graph 20)
    if [[ -n "$log" ]]; then
        while IFS= read -r line; do
            cursor_to "$_LAYOUT_CURSOR_ROW" "$_LAYOUT_CURSOR_COL"
            printf '  %s%s\n' "$line" "$RST"
            layout_advance 1
        done <<< "$log"
    fi

    layout_footer "Press any key to go back..."
    read -rsn1
    render
}

do_sessions() {
    if [[ -n "$C_BG_PRIMARY" ]]; then
        fill_background
    else
        screen_clear
    fi
    layout_init
    layout_header "Tmux Sessions" "$(sys_datetime)"
    layout_section "ALL SESSIONS & WINDOWS"
    layout_spacer

    tmux list-sessions -F "#{session_name}" 2>/dev/null | while IFS= read -r sess; do
        layout_print "  ${sess}" "${BOLD}${C_SECONDARY}"
        tmux list-windows -t "$sess" -F "    #{window_index}: #{window_name} (#{window_panes} panes)" 2>/dev/null | while IFS= read -r win; do
            layout_print "  $win" "$C_MUTED"
        done
    done

    layout_footer "Press any key to go back..."
    read -rsn1
    render
}

do_theme_cycle() {
    local themes=(catppuccin tokyonight dracula nord minimal)
    local current_idx=0
    for i in "${!themes[@]}"; do
        [[ "${themes[$i]}" == "$OVERLAY_THEME" ]] && current_idx=$i
    done
    local next_idx=$(( (current_idx + 1) % ${#themes[@]} ))
    OVERLAY_THEME="${themes[$next_idx]}"
    theme_load "$OVERLAY_THEME"
    data_cache_clear
    render
}

do_quit() {
    input_stop
}

do_help() {
    input_show_help
    render
}

# Register bindings
input_bind "r" "do_refresh"     "efresh"
input_bind "g" "do_git_log"     "it log"
input_bind "s" "do_sessions"    "essions"
input_bind "t" "do_theme_cycle" "heme"
input_bind "?" "do_help"        " help"
input_bind "q" "do_quit"        "uit"
input_bind "escape" "do_quit"   ""

# ============================================================
# Launch
# ============================================================

overlay_start "Terminal Dashboard" "render"
