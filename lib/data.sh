#!/usr/bin/env bash
# tmux-claude-overlay: Data providers
# Pluggable data sources for overlays: git, system, tmux, custom.
# Compatible with bash 3.2+ (no associative arrays).
# Source after colors.sh.

# ============================================================
# Data cache (file-based, works on bash 3.2)
# ============================================================

_DATA_CACHE_DIR=$(mktemp -d "${TMPDIR:-/tmp}/overlay_cache.XXXXXX")

# Clean up cache dir on exit
_data_cleanup() { rm -rf "$_DATA_CACHE_DIR" 2>/dev/null; }
trap '_data_cleanup' EXIT

# Sanitize a key to a safe filename
_cache_key_file() {
    local key="$1"
    # Replace non-alphanumeric with underscore
    echo "${_DATA_CACHE_DIR}/$(echo "$key" | tr -c '[:alnum:]_' '_')"
}

# Cache a value. Usage: data_cache_set "key" "value"
data_cache_set() {
    local file
    file=$(_cache_key_file "$1")
    printf '%s' "$2" > "$file"
}

# Get cached value. Usage: data_cache_get "key"
# Returns 1 if not cached.
data_cache_get() {
    local file
    file=$(_cache_key_file "$1")
    if [[ -f "$file" ]]; then
        cat "$file"
        return 0
    fi
    return 1
}

# Clear all cached data (call between renders if data might change)
data_cache_clear() {
    rm -f "${_DATA_CACHE_DIR}"/* 2>/dev/null
}

# Generic cached fetch: runs command only if not already cached.
# Usage: data_fetch "cache_key" command [args...]
data_fetch() {
    local key="$1"; shift
    local cached
    if cached=$(data_cache_get "$key"); then
        echo "$cached"
        return 0
    fi
    local result
    result=$("$@" 2>/dev/null) || result=""
    data_cache_set "$key" "$result"
    echo "$result"
}

# ============================================================
# Git data provider
# ============================================================

_git_dir() {
    local dir="${1:-$(tmux display-message -p '#{pane_current_path}' 2>/dev/null || pwd)}"
    echo "$dir"
}

git_branch() {
    local dir
    dir=$(_git_dir "${1:-}")
    data_fetch "git_branch" git -C "$dir" branch --show-current
}

git_status_porcelain() {
    local dir
    dir=$(_git_dir "${1:-}")
    data_fetch "git_status" git -C "$dir" status --porcelain
}

git_is_dirty() {
    local status
    status=$(git_status_porcelain "${1:-}")
    [[ -n "$status" ]]
}

git_dirty_count() {
    local status
    status=$(git_status_porcelain "${1:-}")
    if [[ -n "$status" ]]; then
        echo "$status" | wc -l | tr -d ' '
    else
        echo "0"
    fi
}

git_log_oneline() {
    local count="${1:-5}" dir
    dir=$(_git_dir "${2:-}")
    data_fetch "git_log_${count}" git -C "$dir" log --oneline -"$count"
}

git_log_graph() {
    local count="${1:-10}" dir
    dir=$(_git_dir "${2:-}")
    git -C "$dir" log --oneline --graph --decorate --color=always -"$count" 2>/dev/null
}

git_remote_url() {
    local dir
    dir=$(_git_dir "${1:-}")
    data_fetch "git_remote" git -C "$dir" remote get-url origin
}

git_last_commit_time() {
    local dir
    dir=$(_git_dir "${1:-}")
    data_fetch "git_last_time" git -C "$dir" log -1 --format='%ar'
}

git_stash_count() {
    local dir
    dir=$(_git_dir "${1:-}")
    local count
    count=$(git -C "$dir" stash list 2>/dev/null | wc -l | tr -d ' ')
    echo "$count"
}

git_ahead_behind() {
    local dir
    dir=$(_git_dir "${1:-}")
    local upstream
    upstream=$(git -C "$dir" rev-parse --abbrev-ref '@{upstream}' 2>/dev/null) || { echo "no upstream"; return; }
    local ahead behind
    ahead=$(git -C "$dir" rev-list --count "${upstream}..HEAD" 2>/dev/null || echo 0)
    behind=$(git -C "$dir" rev-list --count "HEAD..${upstream}" 2>/dev/null || echo 0)
    echo "↑${ahead} ↓${behind}"
}

# ============================================================
# System data provider
# ============================================================

sys_hostname() { data_fetch "hostname" hostname -s; }

sys_uptime() {
    data_fetch "uptime" bash -c "uptime | sed 's/.*up /up /' | sed 's/,.*//' | xargs"
}

sys_load() {
    data_fetch "load" bash -c "sysctl -n vm.loadavg 2>/dev/null | awk '{print \$2, \$3, \$4}'"
}

sys_cpu_count() {
    data_fetch "cpu_count" sysctl -n hw.ncpu
}

sys_memory_pressure() {
    data_fetch "mem_pressure" bash -c "memory_pressure 2>/dev/null | grep 'System-wide' | head -1 | awk '{print \$NF}'"
}

sys_disk_usage() {
    data_fetch "disk_usage" bash -c "df -h / | tail -1 | awk '{print \$5}'"
}

sys_datetime() { date '+%a %b %d, %H:%M:%S'; }
sys_date()     { date '+%Y-%m-%d'; }
sys_time()     { date '+%H:%M:%S'; }

# ============================================================
# Tmux data provider
# ============================================================

tmux_session_name() {
    data_fetch "tmux_session" tmux display-message -p '#S'
}

tmux_window_name() {
    data_fetch "tmux_window" tmux display-message -p '#W'
}

tmux_window_index() {
    data_fetch "tmux_win_idx" tmux display-message -p '#I'
}

tmux_pane_id() {
    data_fetch "tmux_pane_id" tmux display-message -p '#D'
}

tmux_pane_path() {
    data_fetch "tmux_pane_path" tmux display-message -p '#{pane_current_path}'
}

tmux_pane_command() {
    data_fetch "tmux_pane_cmd" tmux display-message -p '#{pane_current_command}'
}

tmux_session_count() {
    data_fetch "tmux_sess_count" bash -c "tmux list-sessions 2>/dev/null | wc -l | tr -d ' '"
}

tmux_pane_count() {
    data_fetch "tmux_pane_count" bash -c "tmux list-panes 2>/dev/null | wc -l | tr -d ' '"
}

tmux_list_sessions() {
    tmux list-sessions -F '#{session_name}: #{session_windows} windows (#{session_attached} attached)' 2>/dev/null
}

tmux_list_windows() {
    local session="${1:-$(tmux_session_name)}"
    tmux list-windows -t "$session" -F '#{window_index}: #{window_name} (#{window_panes} panes)' 2>/dev/null
}

tmux_list_panes_detail() {
    tmux list-panes -F '#{pane_index}: #{pane_current_command} #{pane_width}x#{pane_height} #{?pane_active,(active),}' 2>/dev/null
}

# ============================================================
# Custom data providers (eval-based for bash 3.2)
# ============================================================

# Register a custom data provider function.
# Usage: data_register "name" "function_name"
data_register() {
    eval "_DATA_PROVIDER_$1=\"$2\""
}

# Fetch from a registered provider.
# Usage: data_get "name"
data_get() {
    local name="$1"
    local var_name="_DATA_PROVIDER_${name}"
    local func
    eval "func=\"\${${var_name}:-}\""
    if [[ -n "$func" ]]; then
        data_fetch "custom_${name}" "$func"
    else
        echo "unknown provider: $name" >&2
        return 1
    fi
}
