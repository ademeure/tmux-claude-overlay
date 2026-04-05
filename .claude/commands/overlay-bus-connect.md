# Connect to Overlay Message Bus

Connect to a running overlay's message bus for bidirectional communication.

**Arguments:** `$ARGUMENTS` — (none required)

## Instructions

1. **Find the active bus:**
   ```bash
   bus_dir=$(cat "${TMPDIR:-/tmp}/overlay_bus_latest" 2>/dev/null)
   ```
   If no bus found, tell the user to launch an overlay first.

2. **Check the bus is alive:**
   ```bash
   cat "$bus_dir/.pid"  # Should show a running PID
   ```

3. **Read current state:**
   ```bash
   ls "$bus_dir/state/"
   for key in $(ls "$bus_dir/state/"); do
     echo "$key = $(cat "$bus_dir/state/$key")"
   done
   ```

4. **Watch for events:**
   ```bash
   ls -lt "$bus_dir/events/" | head -10  # Recent events
   cat "$bus_dir/events/_latest"          # Latest event
   ```

5. **Send commands to the overlay:**
   ```bash
   timestamp=$(date +%s)
   cat > "$bus_dir/commands/${timestamp}_<command_name>" <<EOF
   command: <command_name>
   time: $(date -u +%Y-%m-%dT%H:%M:%SZ)
   payload: <data>
   EOF
   ```

6. **Common patterns:**
   - Send a refresh command: command name `refresh`
   - Send a theme change: command name `theme`, payload `dracula`
   - Read what the user selected: check `events/_latest` for `select` events
   - Set shared state: write to `$bus_dir/state/<key>`

The bus uses a file-based protocol — events go from overlay to orchestrator,
commands go from orchestrator to overlay, and state is shared bidirectionally.
