#!/usr/bin/env bash
# tmux-claude-overlay: Message bus
# Bidirectional communication between overlays and external processes.
# Uses a shared directory with message files for IPC.
#
# Architecture:
#   overlay → bus → orchestrator   (events: user selections, actions)
#   orchestrator → bus → overlay   (commands: update data, trigger refresh)
#
# The bus directory contains:
#   events/    — overlay writes here, orchestrator reads
#   commands/  — orchestrator writes here, overlay reads
#   state/     — shared state files (both read/write)
#
# Source after colors.sh. No other dependencies.

# ============================================================
# Bus initialization
# ============================================================

# Default bus directory (override with OVERLAY_BUS_DIR)
OVERLAY_BUS_DIR="${OVERLAY_BUS_DIR:-${TMPDIR:-/tmp}/overlay_bus_$$}"

# Initialize the bus. Call once at overlay start.
# Usage: bus_init [bus_dir]
bus_init() {
    OVERLAY_BUS_DIR="${1:-$OVERLAY_BUS_DIR}"
    mkdir -p "${OVERLAY_BUS_DIR}/events"
    mkdir -p "${OVERLAY_BUS_DIR}/commands"
    mkdir -p "${OVERLAY_BUS_DIR}/state"

    # Write bus location so external processes can find it
    echo "$$" > "${OVERLAY_BUS_DIR}/.pid"
    echo "$OVERLAY_BUS_DIR" > "${TMPDIR:-/tmp}/overlay_bus_latest"

    # Cleanup on exit
    trap '_bus_cleanup' EXIT
}

_bus_cleanup() {
    # Don't remove bus dir if an external process might still need it
    # Just remove the PID file to signal we're gone
    rm -f "${OVERLAY_BUS_DIR}/.pid" 2>/dev/null
}

# ============================================================
# Events (overlay → orchestrator)
# ============================================================

# Emit an event. External processes can watch the events/ directory.
# Usage: bus_emit "event_name" "payload"
# Creates a timestamped file in events/.
bus_emit() {
    local name="$1" payload="${2:-}"
    local timestamp
    timestamp=$(date +%s%N 2>/dev/null || date +%s)
    local file="${OVERLAY_BUS_DIR}/events/${timestamp}_${name}"

    cat > "$file" <<EOF
event: ${name}
time: $(date -u +%Y-%m-%dT%H:%M:%SZ)
pid: $$
payload: ${payload}
EOF
    # Also write to a "latest" symlink for easy polling
    ln -sf "$file" "${OVERLAY_BUS_DIR}/events/_latest" 2>/dev/null
}

# Emit a structured event with key-value data.
# Usage: bus_emit_data "event_name" "key1=val1" "key2=val2" ...
bus_emit_data() {
    local name="$1"; shift
    local payload=""
    for kv in "$@"; do
        payload="${payload}${kv}\n"
    done
    bus_emit "$name" "$payload"
}

# Common event shortcuts
bus_emit_select()  { bus_emit "select"  "$1"; }  # User selected an item
bus_emit_action()  { bus_emit "action"  "$1"; }  # User triggered an action
bus_emit_input()   { bus_emit "input"   "$1"; }  # User provided text input
bus_emit_dismiss() { bus_emit "dismiss" "$1"; }  # Overlay was dismissed
bus_emit_error()   { bus_emit "error"   "$1"; }  # An error occurred

# ============================================================
# Commands (orchestrator → overlay)
# ============================================================

# Check for pending commands. Returns 0 if commands available.
# Usage: if bus_has_commands; then ... fi
bus_has_commands() {
    local count
    count=$(ls "${OVERLAY_BUS_DIR}/commands/" 2>/dev/null | wc -l | tr -d ' ')
    [[ $count -gt 0 ]]
}

# Read and consume the oldest pending command.
# Usage: bus_read_command
# Prints the command file content and deletes it.
# Returns 1 if no commands pending.
bus_read_command() {
    local oldest
    oldest=$(ls -t "${OVERLAY_BUS_DIR}/commands/" 2>/dev/null | tail -1)
    if [[ -z "$oldest" ]]; then
        return 1
    fi
    local file="${OVERLAY_BUS_DIR}/commands/${oldest}"
    cat "$file"
    rm -f "$file"
    return 0
}

# Process all pending commands through a callback.
# Usage: bus_process_commands "my_handler_function"
# The handler receives the command name as $1 and payload as $2.
bus_process_commands() {
    local handler="$1"
    while bus_has_commands; do
        local content
        content=$(bus_read_command) || break
        local cmd_name
        cmd_name=$(echo "$content" | grep '^command:' | sed 's/^command: *//')
        local cmd_payload
        cmd_payload=$(echo "$content" | grep '^payload:' | sed 's/^payload: *//')
        if [[ -n "$cmd_name" ]]; then
            "$handler" "$cmd_name" "$cmd_payload"
        fi
    done
}

# ============================================================
# Shared state (bidirectional)
# ============================================================

# Write a state value. Both overlay and orchestrator can use this.
# Usage: bus_state_set "key" "value"
bus_state_set() {
    local key="$1" value="$2"
    echo "$value" > "${OVERLAY_BUS_DIR}/state/${key}"
}

# Read a state value.
# Usage: bus_state_get "key" [default]
bus_state_get() {
    local key="$1" default="${2:-}"
    local file="${OVERLAY_BUS_DIR}/state/${key}"
    if [[ -f "$file" ]]; then
        cat "$file"
    else
        echo "$default"
    fi
}

# Check if a state key exists.
bus_state_has() {
    [[ -f "${OVERLAY_BUS_DIR}/state/$1" ]]
}

# List all state keys.
bus_state_keys() {
    ls "${OVERLAY_BUS_DIR}/state/" 2>/dev/null
}

# ============================================================
# Orchestrator helpers (for the OTHER side of the bus)
# ============================================================

# These are meant to be sourced by the orchestrator process.

# Send a command to the overlay.
# Usage: bus_send_command "command_name" "payload"
bus_send_command() {
    local name="$1" payload="${2:-}"
    local timestamp
    timestamp=$(date +%s%N 2>/dev/null || date +%s)
    local file="${OVERLAY_BUS_DIR}/commands/${timestamp}_${name}"

    cat > "$file" <<EOF
command: ${name}
time: $(date -u +%Y-%m-%dT%H:%M:%SZ)
payload: ${payload}
EOF
}

# Wait for the next event from the overlay.
# Usage: bus_wait_event [timeout_seconds]
# Returns 0 and prints event content, or 1 on timeout.
bus_wait_event() {
    local timeout="${1:-30}"
    local start
    start=$(date +%s)
    local last_event=""

    # Record current latest
    if [[ -L "${OVERLAY_BUS_DIR}/events/_latest" ]]; then
        last_event=$(readlink "${OVERLAY_BUS_DIR}/events/_latest" 2>/dev/null)
    fi

    while true; do
        local now
        now=$(date +%s)
        if [[ $((now - start)) -ge $timeout ]]; then
            return 1
        fi

        local current_latest=""
        if [[ -L "${OVERLAY_BUS_DIR}/events/_latest" ]]; then
            current_latest=$(readlink "${OVERLAY_BUS_DIR}/events/_latest" 2>/dev/null)
        fi

        if [[ -n "$current_latest" && "$current_latest" != "$last_event" ]]; then
            cat "$current_latest"
            return 0
        fi

        sleep 0.2
    done
}

# Watch for events continuously, calling a handler for each.
# Usage: bus_watch_events "my_handler" [poll_interval]
# Handler receives: $1=event_name $2=payload
bus_watch_events() {
    local handler="$1" interval="${2:-0.5}"
    local last_event=""

    while true; do
        local current_latest=""
        if [[ -L "${OVERLAY_BUS_DIR}/events/_latest" ]]; then
            current_latest=$(readlink "${OVERLAY_BUS_DIR}/events/_latest" 2>/dev/null)
        fi

        if [[ -n "$current_latest" && "$current_latest" != "$last_event" && -f "$current_latest" ]]; then
            last_event="$current_latest"
            local event_name
            event_name=$(grep '^event:' "$current_latest" | sed 's/^event: *//')
            local event_payload
            event_payload=$(grep '^payload:' "$current_latest" | sed 's/^payload: *//')
            "$handler" "$event_name" "$event_payload"
        fi

        sleep "$interval"
    done
}

# ============================================================
# Bus discovery
# ============================================================

# Find the bus directory of a running overlay.
# Usage: bus_find
# Returns the bus dir path, or 1 if none found.
bus_find() {
    if [[ -f "${TMPDIR:-/tmp}/overlay_bus_latest" ]]; then
        local dir
        dir=$(cat "${TMPDIR:-/tmp}/overlay_bus_latest")
        if [[ -d "$dir" && -f "$dir/.pid" ]]; then
            echo "$dir"
            return 0
        fi
    fi
    return 1
}

# Connect to an existing overlay's bus.
# Usage: source bus.sh; bus_dir=$(bus_find); OVERLAY_BUS_DIR="$bus_dir"
# Then use bus_send_command, bus_wait_event, etc.

# ============================================================
# Input integration: auto-emit events from menu selections
# ============================================================

# Wrap a menu callback to also emit a bus event.
# Usage: menu_init ... "bus_menu_callback"
# Then the bus will emit "select" events with the selected item.
bus_menu_callback() {
    local index="$1" item="$2"
    bus_emit_data "select" "index=${index}" "item=${item}"
}

# Poll for commands during the input loop (call from a timer or render).
# Usage: bus_poll_commands "handler_function"
bus_poll_commands() {
    local handler="$1"
    if bus_has_commands; then
        bus_process_commands "$handler"
    fi
}
