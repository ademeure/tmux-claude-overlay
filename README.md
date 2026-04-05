# tmux-claude-overlay

A bash framework for building beautiful, interactive tmux popup overlays. It provides a layered architecture -- from low-level color primitives up through a widget system and message bus -- so you can build rich terminal dashboards and tool UIs with minimal code.

The included demo overlay renders a responsive two-column dashboard with git status, system info, tmux sessions, commit history, themed card layouts, and keyboard navigation, all inside a tmux popup.

## Quick Start

**Requirements:** bash 3.2+, tmux 3.2+ (for `display-popup`), a terminal with 256-color or truecolor support.

```bash
# Clone the repository
git clone <repo-url> ~/tmux-claude-overlay
cd ~/tmux-claude-overlay

# Launch the demo in a tmux popup (must be inside a tmux session)
bin/overlay launch demo

# Or run directly in the current terminal (no popup)
bin/overlay run demo

# With options
bin/overlay launch demo --theme dracula --style heavy --width 90% --height 90%
```

### CLI Reference

```
bin/overlay list                     # List available overlays
bin/overlay launch <name> [opts]     # Launch in a tmux popup
bin/overlay run <name> [opts]        # Run directly (no popup)
bin/overlay themes                   # List available themes
bin/overlay screenshot <cmd> [args]  # Screenshot tools
```

Options for `launch` and `run`:

| Flag | Default | Description |
|------|---------|-------------|
| `--theme <name>` | `catppuccin` | Color theme |
| `--width <w>` | `80%` | Popup width (percentage or columns) |
| `--height <h>` | `80%` | Popup height (percentage or rows) |
| `--style <s>` | `round` | Box style: `round`, `sharp`, `double`, `heavy` |
| `--no-border` | | Hide the tmux popup border |

## Architecture

The framework is organized as a stack of composable layers. Each file sources the ones below it:

```
overlay.sh          Lifecycle: init, run, cleanup. Sources everything.
  bus.sh            Message bus: IPC between overlays and external processes
  widgets.sh        High-level components: cards, banners, tables, sparklines
  input.sh          Key bindings, input loop, menus, help overlay
  data.sh           Pluggable data providers: git, system, tmux, custom + cache
  layout.sh         Screen detection, grid system, responsive breakpoints
  drawing.sh        Box drawing, cursor control, lines, text, progress bars
  theme.sh          Theme loading and switching (sets semantic color vars)
  colors.sh         ANSI codes, 256-color, truecolor, gradients, strip_ansi
```

Your overlay script sources `lib/overlay.sh` and gets everything:

```bash
#!/usr/bin/env bash
source "$(dirname "$0")/../lib/overlay.sh"
```

## API Reference

### lib/colors.sh -- Color System

Provides named ANSI constants, truecolor helpers, gradients, and string measurement.

#### Constants

```bash
# Reset and attributes
$RST $BOLD $DIM $ITALIC $UNDERLINE $BLINK $REVERSE $HIDDEN $STRIKE

# Standard foreground (8 colors + 8 bright)
$FG_BLACK $FG_RED $FG_GREEN $FG_YELLOW $FG_BLUE $FG_MAGENTA $FG_CYAN $FG_WHITE
$FG_BRIGHT_BLACK $FG_BRIGHT_RED ... $FG_BRIGHT_WHITE

# Standard background (8 + 8 bright)
$BG_BLACK $BG_RED ... $BG_BRIGHT_WHITE

# Semantic colors (overridden by themes)
$C_PRIMARY $C_SECONDARY $C_ACCENT $C_SUCCESS $C_WARNING $C_ERROR
$C_MUTED $C_TEXT $C_HEADING $C_BORDER $C_KEY_HINT
$C_BG_PRIMARY $C_BG_SURFACE $C_BG_HIGHLIGHT
```

#### Functions

```bash
# 256-color
color256_fg 203          # Foreground color 203
color256_bg 17           # Background color 17

# 24-bit truecolor
rgb_fg 137 180 250       # Foreground from RGB values
rgb_bg 30 30 46          # Background from RGB values
hex_fg "#89b4fa"         # Foreground from hex
hex_bg "#1e1e2e"         # Background from hex

# Detection
has_truecolor            # Returns 0 if terminal supports 24-bit color
has_256color             # Returns 0 if terminal supports 256 colors

# Gradients
gradient_fg 137 180 250  30 30 46  3 10
# Interpolated color at step 3 of 10 between two RGB values

gradient_text "Hello World" "#89b4fa" "#cba6f7"
# Prints text with per-character color gradient

# String utilities
strip_ansi "$colored_string"     # Remove all ANSI escape sequences
visible_len "$colored_string"    # Character count excluding ANSI codes
```

---

### lib/theme.sh -- Theme System

Themes set all `THEME_*` variables which are then mapped to the `C_*` semantic colors.

#### Built-in Themes

`catppuccin` (default), `tokyonight`, `dracula`, `nord`, `minimal`

The `minimal` theme uses only basic ANSI colors and works on any terminal.

#### Functions

```bash
theme_load "dracula"     # Load and apply a theme by name
theme_list               # Print all available theme names (built-in + custom)
```

#### Theme Variables Set

Each theme sets these variables (used internally by `_apply_theme`):

```bash
THEME_BG  THEME_BG_SURFACE  THEME_BG_HIGHLIGHT
THEME_FG  THEME_FG_MUTED    THEME_FG_SUBTLE
THEME_PRIMARY  THEME_SECONDARY  THEME_ACCENT
THEME_SUCCESS  THEME_WARNING    THEME_ERROR  THEME_INFO
THEME_BORDER   THEME_BORDER_ACTIVE
THEME_HEX_PRIMARY  THEME_HEX_SECONDARY  THEME_HEX_ACCENT
THEME_HEX_SUCCESS  THEME_HEX_ERROR      THEME_HEX_BG
```

---

### lib/drawing.sh -- Drawing Primitives

Low-level box drawing, cursor control, text rendering, and status indicators.

#### Box Styles

Four built-in character sets: `round`, `sharp`, `double`, `heavy`. Plus block characters for solid fills.

```bash
draw_set_style "heavy"   # Switch active box characters (default: round)

# Character variables available:
# BOX_ROUND_TL="~" BOX_ROUND_TR="~" BOX_ROUND_H="-" BOX_ROUND_V="|" ...
# BOX_SHARP_*, BOX_DOUBLE_*, BOX_HEAVY_*
# BOX_BLOCK_FULL="~" BOX_BLOCK_HALF BOX_BLOCK_QUARTER BOX_BLOCK_MEDIUM BOX_BLOCK_DARK
```

#### Cursor and Screen Control

```bash
cursor_to 5 10           # Move cursor to row 5, column 10 (1-based)
cursor_up 3              # Move cursor up 3 rows
cursor_down 2            # Move cursor down 2 rows
cursor_left 1            # Move cursor left 1 column
cursor_right 4           # Move cursor right 4 columns
cursor_hide              # Hide the cursor
cursor_show              # Show the cursor
cursor_save              # Save cursor position
cursor_restore           # Restore saved cursor position

screen_clear             # Clear the entire screen
erase_eol                # Erase from cursor to end of line
fill_background          # Fill entire screen with theme background color
```

#### Lines and Dividers

```bash
draw_hline 40            # Horizontal line, 40 chars wide
draw_hline 40 "=" "$C_ACCENT"    # Custom character and color

draw_divider "Section" 60         # Labeled divider: -- Section --------
draw_divider "Git" 60 "$C_SUCCESS"  # With custom label color
```

#### Box Drawing

```bash
draw_box 3 5 10 40                # Box at row 3, col 5, 10 rows tall, 40 wide
draw_box 3 5 10 40 "$C_SUCCESS"   # With custom border color

draw_titled_box 3 5 10 40 "Title"             # Box with title in top border
draw_titled_box 3 5 10 40 "Title" "$C_BORDER" "$C_HEADING"
# Interior rows are filled with C_BG_SURFACE
```

#### Text Rendering

```bash
draw_text 5 10 "Hello" "$C_PRIMARY"      # Text at specific row, col
draw_centered "Centered" 80              # Center text in given width
draw_centered "Blue" 80 "$C_PRIMARY"     # With color
draw_right "Right aligned" 80            # Right-align text

draw_kv "Branch" "main"                  # Key-value pair with label width
draw_kv "Branch" "main" "$C_MUTED" "$C_SUCCESS" 20
# Custom colors and label column width (default: 16)
```

#### Status Indicators and Progress

```bash
draw_status "ok" "All tests passing"     # Green dot
draw_status "warn" "3 files changed"     # Yellow half-dot
draw_status "error" "Build failed"       # Red X
draw_status "info" "Deployed"            # Blue diamond

draw_progress 7 10                       # Progress bar: 7/10
draw_progress 7 10 30                    # 30 chars wide
draw_progress 7 10 30 "$C_SUCCESS" "$C_MUTED"   # Custom colors

draw_spinner 0                           # Spinner frame 0 (call in a loop)
draw_spinner "$frame_idx" "$C_ACCENT"    # With color
# Available frame sets: SPINNER_FRAMES, SPINNER_DOTS, SPINNER_SIMPLE
```

#### Cleanup

```bash
draw_cleanup             # Restore cursor, reset colors (call on exit)
```

---

### lib/layout.sh -- Layout Engine

Screen detection, content cursor management, grid system, responsive breakpoints, header/footer.

#### Screen Dimensions

```bash
layout_init              # Detect and set SCREEN_ROWS, SCREEN_COLS, etc.
layout_refresh           # Alias for layout_init

# After init, these globals are available:
# SCREEN_ROWS, SCREEN_COLS           -- full terminal size
# SCREEN_INNER_ROWS, SCREEN_INNER_COLS -- minus padding
# LAYOUT_PAD_TOP, LAYOUT_PAD_BOTTOM, LAYOUT_PAD_LEFT, LAYOUT_PAD_RIGHT
```

Detection tries tmux pane info first (most accurate inside tmux), then `stty size`, then `tput`.

#### Content Cursor

The layout engine maintains a "content cursor" -- the current row where the next piece of content should render.

```bash
layout_row               # Get current content row number
layout_advance 2         # Move content cursor down 2 rows
layout_set_row 10        # Set content cursor to row 10
layout_cursor            # Move terminal cursor to current layout position

layout_spacer            # Insert blank line (advance by 1)
layout_spacer 3          # Insert 3 blank lines
```

#### Content Printing

```bash
layout_print "Some text"             # Print at current position, advance
layout_print "Colored" "$C_SUCCESS"  # With color

layout_kv "Label" "Value"            # Key-value pair at current position
layout_kv "Label" "Value" "$C_MUTED" "$C_SUCCESS"

layout_section "Git Status"          # Divider with title, auto-positioned
layout_section "Git Status" "$C_ACCENT"
```

#### Grid System

```bash
layout_col_width 2           # Width of each column in a 2-column layout
layout_col_width 3 4         # 3 columns with gap of 4

layout_col_start 0 2         # Start column (1-based) for first of 2 columns
layout_col_start 1 2         # Start column for second of 2 columns
```

#### Responsive Breakpoints

```bash
layout_breakpoint            # Returns "narrow" (<60), "medium" (<100), or "wide"
layout_min_width 80          # Returns 0 (true) if screen >= 80 cols
layout_min_height 30         # Returns 0 (true) if screen >= 30 rows
```

#### Header and Footer

```bash
layout_header "Dashboard" "v1.2"     # Header bar with title + optional right text
layout_footer "[q]Quit  [r]Refresh" "catppuccin"
# Footer bar with left hint text + optional right text
```

#### Resize Handling

```bash
layout_on_resize "my_render_function"
# Registers a SIGWINCH trap: refreshes dimensions, then calls your function
```

---

### lib/data.sh -- Data Providers

Pluggable data sources with built-in caching. All git functions auto-detect the working directory from the active tmux pane.

#### Cache

```bash
data_cache_set "mykey" "myvalue"     # Store a value
data_cache_get "mykey"               # Retrieve (returns 1 if missing)
data_cache_clear                     # Clear all cached data

data_fetch "cache_key" command arg1 arg2
# Run command only if not cached; cache and return the result
```

#### Git Provider

```bash
git_branch                           # Current branch name
git_status_porcelain                 # Raw porcelain status
git_is_dirty                         # Returns 0 if working tree has changes
git_dirty_count                      # Number of changed files
git_log_oneline 5                    # Last 5 commits (hash + message)
git_log_graph 10                     # Last 10 commits with graph + color
git_remote_url                       # Origin remote URL
git_last_commit_time                 # Relative time of last commit ("3 hours ago")
git_stash_count                      # Number of stashes
git_ahead_behind                     # "up-arrow2 down-arrow1" vs upstream
```

All git functions accept an optional directory argument: `git_branch "/path/to/repo"`.

#### System Provider

```bash
sys_hostname                         # Short hostname
sys_uptime                           # Uptime string
sys_load                             # Load averages
sys_cpu_count                        # Number of CPU cores
sys_memory_pressure                  # Memory pressure (macOS)
sys_disk_usage                       # Root disk usage percentage
sys_datetime                         # "Mon Apr 05, 14:30:00"
sys_date                             # "2026-04-05"
sys_time                             # "14:30:00"
```

#### Tmux Provider

```bash
tmux_session_name                    # Current session name
tmux_window_name                     # Current window name
tmux_window_index                    # Current window index
tmux_pane_id                         # Current pane ID
tmux_pane_path                       # Pane's working directory
tmux_pane_command                    # Command running in pane
tmux_session_count                   # Number of sessions
tmux_pane_count                      # Number of panes in current window
tmux_list_sessions                   # Formatted session list
tmux_list_windows "session"          # Windows in a session
tmux_list_panes_detail               # Panes with dimensions and activity
```

#### Custom Providers

```bash
# Register a custom data provider
my_weather() { curl -s "wttr.in/?format=3"; }
data_register "weather" "my_weather"

# Fetch from it (uses the cache)
data_get "weather"
```

---

### lib/input.sh -- Input System

Key binding registry, raw key reading, input loop, scrollable menu, and help overlay.

#### Key Bindings

```bash
input_bind "r" "do_refresh" "efresh"
# Bind 'r' key to do_refresh function. Third arg is description for help/footer.
# Convention: omit the first letter from the description (it's the key itself).

input_unbind "r"                     # Remove a binding
input_clear                          # Remove all bindings
```

#### Input Loop

```bash
input_loop               # Blocking loop: reads keys, dispatches to bound callbacks
input_stop               # Break out of the input loop (call from a callback)
```

#### Raw Key Reading

```bash
input_read_key           # Read one key, set $_INPUT_KEY
input_read_key 2         # With 2-second timeout (returns 1 on timeout)
# $_INPUT_KEY will be: a literal character, or one of:
# "escape", "enter", "tab", "space", "backspace",
# "up", "down", "left", "right", "home", "end"
```

#### Menu / List Selection

```bash
menu_init 5 3 10 40 "on_select"
# row=5, col=3, visible_items=10, width=40, callback="on_select"

menu_add_item "First item"
menu_add_item "Second item"
menu_add_item "Third item"

menu_render                          # Draw the menu
menu_bind_keys                       # Bind up/down/j/k/enter to menu nav

menu_selected_index                  # Current selection index
menu_selected_item                   # Current selection text

# The callback receives: $1=index $2=item_text
on_select() { echo "Selected: $2"; }
```

#### Help Overlay

```bash
input_show_help          # Pop up a modal showing all key bindings
# Automatically reads binding descriptions from the registry.

input_hint_string        # Returns "[r]efresh  [q]uit" style string for footers
```

---

### lib/widgets.sh -- Widget Library

High-level UI components that handle layout positioning automatically.

#### Text Utilities

```bash
truncate_text "Long string here" 20  # "Long string here..." (with ellipsis)
pad_text "Short" 20                  # "Short               " (right-padded)
shorten_path "/Users/foo/projects/bar/baz" 30   # "~/...bar/baz"
```

#### Banner

```bash
widget_banner "Dashboard"            # Centered title with gradient (if truecolor)
widget_banner "Dashboard" "v1.0"     # With subtitle
```

#### Cards

```bash
# Manual card with custom content
widget_card_begin "Git Status"
layout_print "Branch: main"
layout_kv "Dirty files" "3"
widget_card_end

# Card with specific width
widget_card_begin "Narrow Card" 40

# Shorthand: card with key-value pairs
widget_info_card "System" \
    "Hostname"  "macbook" \
    "Uptime"    "3 days" \
    "Disk"      "45%"
# Values containing "clean"/"ok" auto-color green; "dirty"/"changed" auto-color yellow.
```

#### Stat Row

```bash
widget_stat_row \
    "Branch"   "main" \
    "Sessions" "3" \
    "Load"     "1.2 0.8 0.5"
# Renders a horizontal row of labeled big values, evenly spaced.
```

#### Badges

```bash
widget_badge "PASSING" "ok"          # Green pill
widget_badge "WARNING" "warn"        # Yellow pill
widget_badge "FAILED" "error"        # Red pill
widget_badge "v2.1" "info"           # Blue pill
widget_badge "tag" "muted"           # Dim pill
widget_badge "inline" "ok" "--inline"  # No line advance
```

#### Status Lines

```bash
widget_status_line "Build" "passing" "ok"
widget_status_line "Tests" "3 failing" "error"
# Renders: "Build          * passing"
```

#### Tables

```bash
widget_table_begin "Name" "Status" "Time"
widget_table_row "deploy-api" "success" "2m ago"
widget_table_row "deploy-web" "running" "just now"
widget_table_row "test-suite" "failed"  "5m ago"
```

#### Lists

```bash
widget_list_item "*" "First item"
widget_list_item ">" "Second item" "$C_SUCCESS"
```

#### Sparklines

```bash
widget_sparkline "CPU" 20 45 30 60 80 55 40
# Renders: "CPU            **********" (using block characters)

widget_sparkline "Memory" 512 600 580 --max 1024
# Scale values against a known maximum
```

#### Separators and Empty States

```bash
widget_separator                     # Dotted line
widget_separator 40                  # Specific width

widget_empty "No results found"      # Centered empty state message
widget_empty "Nothing here" "X"      # With custom icon
```

#### Commit List

```bash
widget_commit_list 5                 # Last 5 commits, formatted with hash + message
widget_commit_list 10 "/path/to/repo"  # From a specific repo
```

#### Quick Overlay (Declarative DSL)

Build a complete overlay from a heredoc without writing a render function:

```bash
source lib/overlay.sh

quick_overlay "My Dashboard" <<'LAYOUT'
  banner My App
  spacer
  card "Status"
    kv "Version" "1.2.3"
    kv "Uptime" "3 days"
    status Build passing ok
    status Tests running info
  end
  spacer
  card "Recent Commits"
    commits 5
  end
LAYOUT
```

DSL commands: `card`, `end`, `kv`, `status`, `commits`, `spacer`, `banner`, `separator`. Unknown lines are printed as text.

---

### lib/bus.sh -- Message Bus

File-based IPC for communication between overlays and external processes (orchestrators, scripts, Claude Code agents, etc.).

#### Initialization

```bash
bus_init                             # Create bus directory, write PID
bus_init "/tmp/my_custom_bus"        # Use a specific directory
# Default: $TMPDIR/overlay_bus_$$
```

The bus directory structure:

```
$OVERLAY_BUS_DIR/
  events/       Overlay writes, orchestrator reads
  commands/     Orchestrator writes, overlay reads
  state/        Shared key-value state (both sides)
  .pid          PID of the overlay process
```

#### Events (Overlay --> External)

```bash
bus_emit "refresh" "user requested"  # Emit a named event with payload

bus_emit_data "select" "index=2" "item=deploy"
# Emit with structured key=value data

# Convenience shortcuts
bus_emit_select "item_name"
bus_emit_action "deploy"
bus_emit_input "search query"
bus_emit_dismiss "user_quit"
bus_emit_error "connection failed"
```

#### Commands (External --> Overlay)

```bash
# In overlay: check for and process commands
if bus_has_commands; then
    content=$(bus_read_command)       # Read + delete oldest command
fi

bus_process_commands "my_handler"
# Calls my_handler with $1=command_name $2=payload for each pending command

bus_poll_commands "my_handler"
# Non-blocking: process commands only if any exist
```

#### Shared State

```bash
bus_state_set "selected_tab" "git"
bus_state_get "selected_tab"         # Returns "git"
bus_state_get "missing" "default"    # Returns "default" if key missing
bus_state_has "selected_tab"         # Returns 0 if key exists
bus_state_keys                       # List all state keys
```

#### Orchestrator Helpers (External Process Side)

These functions are used by the process on the other side of the bus:

```bash
# Source bus.sh in your orchestrator script
source /path/to/lib/bus.sh

# Find the running overlay's bus
OVERLAY_BUS_DIR=$(bus_find)

# Send a command to the overlay
bus_send_command "update_data" "new_value_here"

# Wait for the next event (blocking, with timeout)
event=$(bus_wait_event 30)

# Watch events continuously
handle_event() { echo "Got: $1 = $2"; }
bus_watch_events "handle_event" 0.5   # Poll every 0.5s
```

#### Menu Integration

```bash
menu_init 5 3 10 40 "bus_menu_callback"
# Automatically emits "select" events when the user picks a menu item
```

---

### lib/overlay.sh -- Overlay Lifecycle

The top-level loader. Sources all libraries and provides lifecycle management.

```bash
source "$(dirname "$0")/../lib/overlay.sh"

overlay_init "My Overlay"
# Hides cursor, fills background, initializes layout, sets up cleanup trap.

overlay_run "render_fn"
# Calls render_fn, registers it for SIGWINCH resize, enters input_loop.

# Or combine both:
overlay_start "My Overlay" "render_fn"
```

#### Overlay Registry

```bash
overlay_list             # List overlays in the overlays/ directory with descriptions
overlay_path "demo"      # Get full path to an overlay script
```

## Creating an Overlay

Here is a step-by-step guide to building a custom overlay.

### 1. Create the script

Create `overlays/my_overlay.sh`:

```bash
#!/usr/bin/env bash
# Description: My custom overlay

OVERLAY_ROOT="${OVERLAY_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
source "${OVERLAY_ROOT}/lib/overlay.sh"
```

### 2. Write a render function

The render function draws everything on screen. It will be called on startup and on terminal resize.

```bash
render() {
    # Re-fill background and reset layout on each render
    [[ -n "$C_BG_PRIMARY" ]] && fill_background || screen_clear
    layout_init

    # Banner
    widget_banner "My Overlay" "$(sys_time)"

    # Content
    widget_info_card "Status" \
        "Branch" "$(git_branch)" \
        "Dirty"  "$(git_dirty_count) files"

    layout_spacer

    widget_card_begin "Recent Commits"
    widget_commit_list 5
    widget_card_end

    # Footer with key hints
    layout_footer "$(input_hint_string)" "$OVERLAY_THEME"
}
```

### 3. Bind keys

```bash
do_refresh() { data_cache_clear; render; }
do_quit()    { input_stop; }

input_bind "r" "do_refresh" "efresh"
input_bind "q" "do_quit"    "uit"
input_bind "?" "input_show_help" " help"
input_bind "escape" "do_quit" ""
```

### 4. Start the overlay

```bash
overlay_start "My Overlay" "render"
```

### 5. Launch it

```bash
bin/overlay launch my_overlay
bin/overlay launch my_overlay --theme tokyonight --style double
```

### Responsive Layout

Use `layout_breakpoint` to adapt to different terminal sizes:

```bash
render() {
    # ...
    local bp=$(layout_breakpoint)
    if [[ "$bp" == "wide" ]]; then
        # Two-column layout
        local half=$(( (SCREEN_INNER_COLS - 3) / 2 ))
        local save_row=$_LAYOUT_CURSOR_ROW

        widget_card_begin "Left" "$half"
        # ... left content ...
        widget_card_end

        _LAYOUT_CURSOR_ROW=$save_row
        _LAYOUT_CURSOR_COL=$((_LAYOUT_CURSOR_COL + half + 3))

        widget_card_begin "Right" "$half"
        # ... right content ...
        widget_card_end
    else
        # Single column, stacked
        widget_card_begin "Left"
        # ...
        widget_card_end
        widget_card_begin "Right"
        # ...
        widget_card_end
    fi
}
```

## Themes

### Using Themes

Set the theme via environment variable or CLI flag:

```bash
OVERLAY_THEME=dracula bin/overlay run demo
bin/overlay launch demo --theme nord
```

Cycle themes at runtime by calling `theme_load` and re-rendering:

```bash
do_theme_cycle() {
    local themes="catppuccin tokyonight dracula nord minimal"
    # ... pick next theme ...
    theme_load "$next_theme"
    data_cache_clear
    render
}
input_bind "t" "do_theme_cycle" "heme"
```

### Creating a Custom Theme

Create a file in `config/themes/`, e.g. `config/themes/solarized.sh`:

```bash
# config/themes/solarized.sh
THEME_BG=$(hex_bg "#002b36")
THEME_BG_SURFACE=$(hex_bg "#073642")
THEME_BG_HIGHLIGHT=$(hex_bg "#586e75")

THEME_FG=$(hex_fg "#839496")
THEME_FG_MUTED=$(hex_fg "#586e75")
THEME_FG_SUBTLE=$(hex_fg "#657b83")

THEME_PRIMARY=$(hex_fg "#268bd2")
THEME_SECONDARY=$(hex_fg "#6c71c4")
THEME_ACCENT=$(hex_fg "#b58900")
THEME_SUCCESS=$(hex_fg "#859900")
THEME_WARNING=$(hex_fg "#cb4b16")
THEME_ERROR=$(hex_fg "#dc322f")
THEME_INFO=$(hex_fg "#2aa198")
THEME_BORDER=$(hex_fg "#586e75")
THEME_BORDER_ACTIVE=$(hex_fg "#268bd2")

THEME_HEX_PRIMARY="#268bd2"
THEME_HEX_SECONDARY="#6c71c4"
THEME_HEX_ACCENT="#b58900"
THEME_HEX_SUCCESS="#859900"
THEME_HEX_ERROR="#dc322f"
THEME_HEX_BG="#002b36"
```

Then use it: `bin/overlay launch demo --theme solarized`

## Screenshot Tooling

The `tools/screenshot.sh` script captures overlay output for visual iteration -- useful when building UIs with Claude or when reviewing changes across themes.

```bash
# Capture current tmux pane (with ANSI codes)
tools/screenshot.sh capture-text

# Capture to a specific file
tools/screenshot.sh capture-text "" my_capture.txt

# Automated preview: launch overlay in detached pane, capture, teardown
tools/screenshot.sh preview overlays/demo.sh --theme dracula --width 100 --height 30

# Interactive preview: launch in popup, capture on dismiss
tools/screenshot.sh interactive-preview overlays/demo.sh catppuccin

# Render all themes for comparison
tools/screenshot.sh batch-themes overlays/demo.sh

# Diff two captures
tools/screenshot.sh compare screenshots/a.txt screenshots/b.txt

# List all captures
tools/screenshot.sh gallery
```

Captures are saved to `screenshots/` with timestamped filenames.

## Message Bus

The message bus enables overlays to communicate with external processes. This is how you connect an overlay to a backend, a Claude Code agent, or any script that needs to send data in or receive user actions out.

### Example: Orchestrator Script

```bash
#!/usr/bin/env bash
source /path/to/lib/bus.sh

# Find the running overlay's bus
OVERLAY_BUS_DIR=$(bus_find) || { echo "No overlay running"; exit 1; }

# Send a command
bus_send_command "set_status" "deploying"

# Update shared state
bus_state_set "deploy_progress" "45"

# Wait for user action
event=$(bus_wait_event 60)
echo "User did: $event"
```

### Example: Overlay Receiving Commands

```bash
handle_command() {
    local cmd="$1" payload="$2"
    case "$cmd" in
        set_status)    STATUS="$payload"; render ;;
        refresh)       data_cache_clear; render ;;
    esac
}

# Poll during render or on a timer
bus_poll_commands "handle_command"
```

## Configuration

Default settings are in `config/defaults.sh` and can be overridden via environment variables:

| Variable | Default | Description |
|----------|---------|-------------|
| `OVERLAY_THEME` | `catppuccin` | Color theme |
| `OVERLAY_STYLE` | `round` | Box drawing style |
| `OVERLAY_WIDTH` | `80%` | Popup width |
| `OVERLAY_HEIGHT` | `80%` | Popup height |
| `LAYOUT_PAD_TOP` | `1` | Top padding |
| `LAYOUT_PAD_BOTTOM` | `1` | Bottom padding |
| `LAYOUT_PAD_LEFT` | `2` | Left padding |
| `LAYOUT_PAD_RIGHT` | `2` | Right padding |
| `OVERLAY_SCREENSHOT_DIR` | `screenshots` | Screenshot output directory |

## Project Structure

```
tmux-claude-overlay/
  bin/overlay              CLI launcher
  config/
    defaults.sh            Default configuration
    themes/                Custom theme files (.sh)
  lib/
    colors.sh              Color system
    theme.sh               Theme loading
    drawing.sh             Drawing primitives
    layout.sh              Layout engine
    data.sh                Data providers + cache
    input.sh               Input handling
    widgets.sh             Widget library
    bus.sh                 Message bus
    overlay.sh             Framework loader + lifecycle
  overlays/
    demo.sh                Demo dashboard overlay
  screenshots/             Captured output (gitignored)
  tools/
    screenshot.sh          Screenshot and preview tooling
```

## License

MIT
