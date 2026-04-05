# tmux-claude-overlay: Architecture, Trade-offs, and Future Directions

This document describes the internal architecture of the tmux-claude-overlay
framework, the reasoning behind its design decisions, and a vision for where
the project could go next.

---

## Part 1: Architecture

### 1. System Diagram

```
 User
  |
  v
+------------------------------------------------------+
| bin/overlay  (CLI entry point)                        |
|   list | launch | run | themes | screenshot           |
+------+-------+----+---------+------------------------+
       |       |    |         |
       |  tmux display-popup  |   (direct bash exec)
       |       |              |
       v       v              v
+------------------------------------------------------+
| overlays/*.sh  (overlay scripts)                     |
|   e.g. demo.sh                                        |
|   source lib/overlay.sh  (loads full framework)       |
|   define render()  -->  overlay_start "Title" render   |
+------+-----------------------------------------------+
       |
       |  source
       v
+------------------------------------------------------+
|                  lib/overlay.sh                        |
|                 (framework loader)                     |
|                                                        |
|  Sources in order:                                     |
|    colors.sh -> theme.sh -> drawing.sh -> layout.sh   |
|    -> data.sh -> input.sh -> widgets.sh -> bus.sh     |
|                                                        |
|  Provides lifecycle: overlay_init / overlay_run /      |
|                      overlay_start                     |
+------+-----------------------------------------------+
       |
       v
+------------------------------------------------------+
|                   Library Layer                        |
|                                                        |
|  +------------+  +------------+  +-----------+        |
|  | colors.sh  |  | theme.sh   |  | drawing.sh|        |
|  | ANSI codes |  | 5 built-in |  | box chars |        |
|  | hex/rgb    |  | themes     |  | cursor    |        |
|  | gradients  |  | semantic   |  | progress  |        |
|  | detection  |  | mapping    |  | spinners  |        |
|  +-----+------+  +-----+------+  +-----+-----+       |
|        |               |               |              |
|  +-----v------+  +-----v------+  +-----v-----+       |
|  | layout.sh  |  | data.sh    |  | input.sh  |       |
|  | dimensions |  | git/sys/   |  | key bind  |       |
|  | grid cols  |  | tmux data  |  | menus     |       |
|  | breakpoints|  | file cache |  | input loop|       |
|  | header/ftr |  | providers  |  | help modal|       |
|  +-----+------+  +-----+------+  +-----+-----+       |
|        |               |               |              |
|        +-------+-------+-------+-------+              |
|                |                                       |
|          +-----v------+                                |
|          | widgets.sh |                                |
|          | banner     |                                |
|          | cards      |                                |
|          | tables     |                                |
|          | badges     |                                |
|          | sparklines |                                |
|          | quick DSL  |                                |
|          +-----+------+                                |
|                |                                       |
|          +-----v------+                                |
|          |  bus.sh    |                                |
|          | events     |                                |
|          | commands   |                                |
|          | state      |                                |
|          | discovery  |                                |
|          +------------+                                |
+------------------------------------------------------+
       |
       v
+------------------------------------------------------+
| External Integrations                                 |
|                                                        |
|  +------------+  +-----------+  +------------------+  |
|  | tmux       |  | git       |  | macOS system     |  |
|  | popups     |  | branches  |  | hostname, load   |  |
|  | pane info  |  | status    |  | disk, memory     |  |
|  | sessions   |  | log       |  | screencapture    |  |
|  +------------+  +-----------+  +------------------+  |
|                                                        |
|  +---------------------------------------------------+|
|  | tools/screenshot.sh                                ||
|  |   capture-text, capture-image, preview, compare    ||
|  +---------------------------------------------------+|
+------------------------------------------------------+
```

### 2. Data Flow

Data moves through the system in a unidirectional pipeline with a feedback
loop through the input system:

```
  External Sources          Framework Core            Terminal
  ================          ==============            ========

  git commands ----+
  tmux queries ---+|   +------------------+
  system utils --+||   |    data.sh       |
                 |||   | (file-based      |    +-------------+
                 |||-->|  cache layer)    |--->| Provider     |
                 |||   |                  |    | functions    |
                 |||   +------------------+    | git_branch() |
                 |||                            | sys_load()   |
                 |||                            +------+------+
                 |||                                   |
                 |||                                   v
                 |||                            +------+------+
                 |||                            | Overlay      |
                 |||                            | render()     |
                 |||                            | function     |
                 |||                            +------+------+
                 |||                                   |
                 |||    uses widgets.sh, layout.sh,    |
                 |||    drawing.sh, theme.sh            |
                 |||                                   v
                 |||                            +------+------+
                 |||                            | ANSI escape  |
                 |||                            | sequences    |
                 |||                            | (stdout)     |
                 |||                            +------+------+
                 |||                                   |
                 |||                                   v
                 |||                            +-----------+
                 |||                            | Terminal   |
                 |||       WINCH signal         | emulator   |
                 |||<-----------+---------------| (iTerm2,   |
                                |               | Kitty, etc)|
                                |               +-----+-----+
                                |                     |
                         +------+------+              |
                         | layout.sh   |       keystrokes
                         | on_resize   |              |
                         | re-renders  |              v
                         +-------------+       +------+------+
                                               | input.sh    |
                                               | read_key()  |
                                               | dispatch to |
                                               | callbacks   |
                                               +------+------+
                                                      |
                         +----------------------------+
                         |
                         v
                  +------+------+
                  | bus.sh       |
                  | (IPC layer)  |
                  | events out   |
                  | commands in  |
                  +-------------+
```

The key data flow steps:

1. **Provider fetch**: Overlay calls a provider function like `git_branch()`.
   The provider calls `data_fetch()` which checks the file-based cache.
   On a cache miss, it runs the actual command (e.g., `git branch --show-current`)
   and stores the result in a temp file.

2. **Render**: The overlay's render function uses the fetched data to compose
   the display using widgets, layout helpers, and drawing primitives. All output
   is ANSI escape sequences written to stdout.

3. **Display**: The terminal emulator interprets the escape sequences and
   renders the visual output.

4. **Input**: The input loop reads keystrokes, dispatches them through the
   key binding registry, and triggers callbacks that may re-render, navigate
   to sub-views, or emit bus events.

5. **Resize**: When the terminal is resized, SIGWINCH fires, `layout_refresh()`
   updates the screen dimensions, and the render function is called again.

6. **Bus**: The overlay can emit events (user selections, actions) and receive
   commands (data updates, refresh triggers) through file-based IPC.

### 3. Rendering Pipeline

The rendering pipeline follows a strict sequence:

```
overlay_start("Title", render_fn)
  |
  +---> overlay_init("Title")
  |       |
  |       +---> trap _overlay_cleanup EXIT INT TERM
  |       |       (ensures terminal restoration on any exit)
  |       |
  |       +---> cursor_hide()
  |       |       (hide cursor for clean rendering)
  |       |
  |       +---> fill_background()
  |       |       (paint every cell with C_BG_PRIMARY)
  |       |       - gets terminal size via tput
  |       |       - loops over every row, prints spaces with bg color
  |       |       OR screen_clear() if no bg color (minimal theme)
  |       |
  |       +---> layout_init()
  |               (detect terminal dimensions)
  |               - tries tmux pane_width/pane_height first
  |               - falls back to stty size
  |               - falls back to tput lines/cols
  |               - computes SCREEN_INNER_ROWS/COLS from padding
  |               - sets _LAYOUT_CURSOR_ROW/COL to top-left content area
  |
  +---> overlay_run(render_fn)
          |
          +---> render_fn()
          |       (first render)
          |       Typical render function does:
          |         1. fill_background() or screen_clear()
          |         2. layout_init()
          |         3. widget_banner("Title", "Subtitle")
          |         4. widget_stat_row(...)
          |         5. Fetch data from providers
          |         6. widget_card_begin("Section")
          |         7.   layout_kv / layout_print / draw_status
          |         8. widget_card_end()
          |         9. layout_footer(hints, theme_name)
          |
          +---> layout_on_resize(render_fn)
          |       (register SIGWINCH handler)
          |       On resize: layout_refresh() then render_fn()
          |
          +---> input_loop()
                  (blocking loop)
                  while _INPUT_RUNNING:
                    input_read_key()
                    look up callback via _input_get_callback()
                    execute callback (may re-render, stop loop, etc.)
```

**Widget card rendering detail** (the begin/end pattern):

```
widget_card_begin("Title")
  |
  +---> Save _CARD_START_ROW, _CARD_COL, _CARD_WIDTH
  +---> Draw top border:  ╭─ Title ──────────────╮
  +---> layout_advance(1)
  +---> Indent: _LAYOUT_CURSOR_COL += 2
  |
  ... overlay writes content using layout_kv, layout_print, etc ...
  ... each call advances _LAYOUT_CURSOR_ROW by 1 ...
  |
widget_card_end()
  |
  +---> Restore _LAYOUT_CURSOR_COL
  +---> Draw side borders for rows between start+1 and current:
  |       ╭─ Title ──────────────╮
  |       │  content line 1      │  <-- retroactive side borders
  |       │  content line 2      │
  +---> Draw bottom border:  ╰──────────────────╯
  +---> layout_advance(1)
  +---> Reset column to default padding
```

### 4. Terminal Compatibility

**Bash 3.2 constraints**: macOS ships bash 3.2 (2007), which lacks associative
arrays, `declare -A`, `mapfile`/`readarray`, `${var,,}` lowercase expansion,
and `|&` pipe shorthand. The framework is designed to work on this version.

Workarounds used throughout the codebase:

| Feature Needed            | Bash 4+ Way           | Our Bash 3.2 Approach               |
|---------------------------|-----------------------|--------------------------------------|
| Key-value store           | `declare -A map`      | `eval` with sanitized variable names |
| Data cache                | Associative array     | File-based: one temp file per key    |
| Custom providers          | Associative array     | `eval` with `_DATA_PROVIDER_` prefix |
| Lowercase string          | `${var,,}`            | `tr '[:upper:]' '[:lower:]'`         |
| Array append              | `arr+=("item")`      | `arr[${#arr[@]}]="item"`            |
| String contains           | `[[ $a == *b* ]]`    | `case ",$seen," in *",$key,"*)`      |
| Read into array           | `mapfile -t arr`      | `while IFS= read -r line` loop       |

**Terminal detection**: The color system (`colors.sh`) detects terminal
capabilities at three tiers:

- **Truecolor (24-bit)**: Checks `$COLORTERM == "truecolor"` or `"24bit"`,
  or `$ITERM_SESSION_ID` presence. Enables `hex_fg`/`hex_bg` for full
  palette themes.
- **256-color**: Checks `$TERM` contains `"256color"`. Enables `color256_fg`/
  `color256_bg` helpers.
- **Basic 16-color**: Always available. The `minimal` theme uses only these,
  making it work on any terminal.

**Screen size detection** (`layout.sh`) uses a three-tier fallback:

1. `tmux display-message -p '#{pane_width}'` -- most reliable inside tmux
2. `stty size` -- works on real terminals
3. `tput lines`/`tput cols` -- last resort (can be wrong in subshells)

### 5. IPC Design (Message Bus)

The bus (`bus.sh`) provides bidirectional IPC between overlays and external
orchestrator processes through the filesystem:

```
Bus Directory Layout
====================

$OVERLAY_BUS_DIR/           (default: $TMPDIR/overlay_bus_$$)
  |
  +-- .pid                  Overlay's PID (presence = alive)
  |
  +-- events/               Overlay --> Orchestrator
  |     +-- 1712345678_select     Timestamped event files
  |     +-- 1712345679_action     (name+nanosecond timestamp)
  |     +-- _latest --> ...       Symlink to most recent event
  |
  +-- commands/             Orchestrator --> Overlay
  |     +-- 1712345680_refresh    Timestamped command files
  |     +-- 1712345681_update
  |
  +-- state/                Bidirectional shared state
        +-- current_tab     Simple key-value files
        +-- selected_item   (one file per key, content = value)
        +-- theme
```

**Event flow** (overlay to external):

```
User presses key  --->  input callback  --->  bus_emit("select", "item_3")
                                                |
                                                v
                                          Creates file:
                                          events/1712345678123456_select
                                          Contents:
                                            event: select
                                            time: 2026-04-05T12:00:00Z
                                            pid: 12345
                                            payload: item_3
                                                |
                                                v
                                          Symlinks:
                                          events/_latest --> that file
```

**Command flow** (external to overlay):

```
Orchestrator calls:  bus_send_command("refresh", "git_data")
                       |
                       v
                 Creates file:
                 commands/1712345680123456_refresh
                 Contents:
                   command: refresh
                   time: 2026-04-05T12:00:01Z
                   payload: git_data
                       |
                       v
Overlay polls:   bus_poll_commands("my_handler")
                   |
                   +---> bus_has_commands() checks ls count
                   +---> bus_read_command() reads oldest, deletes it
                   +---> my_handler "refresh" "git_data"
```

**Discovery**: When a bus is initialized, it writes its directory path to
`$TMPDIR/overlay_bus_latest`. External processes call `bus_find()` to locate
a running overlay's bus directory, then use `bus_send_command()`,
`bus_wait_event()`, or `bus_watch_events()` to communicate.

**State**: The `state/` subdirectory provides simple key-value persistence.
Both sides can read and write. Each key is a file, the content is the value.
This avoids race conditions inherent in shared in-memory state by relying on
atomic filesystem operations.

### 6. Theme System

Themes flow from definition through semantic colors to rendering:

```
Theme Definition              Semantic Layer              Rendering
================              ==============              =========

_theme_catppuccin()           _apply_theme()              widgets/drawing
  THEME_BG=#1e1e2e  -------> C_BG_PRIMARY  ------------> fill_background()
  THEME_BG_SURFACE=#313244 -> C_BG_SURFACE  ------------> layout_header()
  THEME_BG_HIGHLIGHT=#45475a> C_BG_HIGHLIGHT ------------> menu highlight
  THEME_FG=#cdd6f4  -------> C_TEXT  --------------------> layout_print()
  THEME_FG_MUTED=#6c7086 --> C_MUTED  ------------------> draw_kv() labels
  THEME_FG_SUBTLE=#a6adc8    (not directly mapped)
  THEME_PRIMARY=#89b4fa ----> C_PRIMARY  ----------------> widget_banner()
                              C_HEADING (BOLD+PRIMARY) --> layout_section()
  THEME_SECONDARY=#cba6f7 -> C_SECONDARY  --------------> session names
  THEME_ACCENT=#f9e2af -----> C_ACCENT  -----------------> commit hashes
  THEME_SUCCESS=#a6e3a1 ----> C_SUCCESS  ----------------> draw_status("ok")
  THEME_WARNING=#fab387 ----> C_WARNING  ----------------> draw_status("warn")
  THEME_ERROR=#f38ba8 ------> C_ERROR  ------------------> draw_status("error")
  THEME_INFO=#89dceb -------> C_INFO (not in apply)        (used via THEME_)
  THEME_BORDER=#585b70 -----> C_BORDER  -----------------> card borders
  THEME_BORDER_ACTIVE=#89b4fa (used directly)  ----------> active card borders
```

The two-tier architecture (THEME_ variables and C_ semantic variables) means:

- **Theme authors** think in terms of palette colors (background, foreground,
  accent colors). They define `THEME_*` variables.
- **Widget/overlay authors** think in terms of purpose (heading, muted text,
  error indicator). They use `C_*` variables.
- **The mapping** (`_apply_theme()`) bridges the two. It also composes values,
  e.g., `C_HEADING = BOLD + THEME_PRIMARY`.

Theme loading (`theme_load()`) checks three sources in order:

1. Built-in function: `_theme_catppuccin`, `_theme_tokyonight`, etc.
2. Custom file: `config/themes/<name>.sh`
3. Fallback: warns and uses catppuccin

The `THEME_HEX_*` variables carry raw hex values for features that need
numeric color manipulation, like `gradient_text()` which interpolates
per-character between two colors.

The `minimal` theme is special: it uses no truecolor or 256-color escapes,
only basic ANSI codes (`$FG_BRIGHT_CYAN`, `$DIM`, `$REVERSE`), so it works
on any terminal from xterm to a serial console.

---

## Part 2: Trade-offs and Design Decisions

### File-based Cache vs Associative Arrays

**Decision**: Use a temp directory with one file per cache key instead of a
bash associative array.

**Why**: Bash 3.2 (macOS default) does not support `declare -A`. We could
require bash 4+, but that would force users to install homebrew bash and
configure their shell, adding friction. The file-based approach works
everywhere.

**Trade-off**: Filesystem I/O is slower than in-memory lookups. Each
`data_cache_get()` does a file existence check and a `cat`. On macOS with
APFS, this is fast enough (~1ms per read) because the files are tiny and
often in the buffer cache. For a dashboard that renders once per user action,
this latency is imperceptible.

**Alternative considered**: We could use `eval` to store cache values in
dynamically named variables (like we do for key bindings), but shell variables
have no easy way to list all entries for `data_cache_clear()`, and the values
can contain arbitrary text including newlines, quotes, and special characters.
Files handle all of this naturally.

### Eval-based Key Bindings vs Associative Arrays

**Decision**: Store key bindings as `_BIND_<sanitized_key>_callback` and
`_BIND_<sanitized_key>_desc` variables, managed through `eval`.

**Why**: Key binding values are simple (function names, short descriptions)
with a small, bounded keyspace. The sanitization function (`_key_san()`)
maps special keys like "escape" and "?" to safe variable suffixes. Unlike
the data cache, we need fast lookup (called on every keystroke) and the
values are predictable.

**Trade-off**: `eval` is inherently risky -- it can execute arbitrary code
if inputs are not sanitized. We mitigate this by only using it internally
with controlled key names. Overlay authors call `input_bind "q" "my_func" "desc"`
and the framework sanitizes the key before eval.

**Why not the file approach here**: The input loop is the hot path. Reading
a file per keystroke would add visible latency, especially with the
`input_read_key()` timeout dance for escape sequences.

### Tmux Pane Size Detection vs tput

**Decision**: Prefer `tmux display-message -p '#{pane_width}'` over
`tput cols` for terminal dimensions.

**Why**: When running inside a tmux popup (the primary use case), `tput`
can return the dimensions of the *outer* terminal, not the popup. Tmux's
internal query returns the popup's actual size. This is critical for layout
calculations -- a 60-column popup on a 200-column terminal would render
completely wrong if we used the outer terminal's width.

**Trade-off**: This ties the framework to tmux. The three-tier fallback
(tmux -> stty -> tput) means it still works outside tmux, but tmux is the
primary target. If someone wanted to use this in a plain terminal without
tmux, `stty size` would take over and generally work correctly.

### Render-on-demand vs Continuous Refresh

**Decision**: Only re-render when triggered by user action or SIGWINCH,
not on a timer.

**Why**: Continuous refresh (like `watch` or `htop`) would require a timer
in the input loop, complicating the architecture. It would also cause
flickering since we do full-screen redraws. The data displayed (git status,
tmux sessions) changes infrequently and is best refreshed explicitly.

**Trade-off**: Data can become stale. The "r" key binding in the demo calls
`data_cache_clear(); render()` to force a refresh. If we wanted live-updating
data, we would need either a background polling loop with a signaling
mechanism, or integration with the bus for push-based updates.

The `data_cache_clear()` function is the refresh primitive. It wipes all
cached values so the next render re-fetches everything.

### Widget card_begin/end Pattern vs Single-call Widgets

**Decision**: Cards use a begin/end pattern where content is rendered between
the two calls, rather than passing content as arguments.

**Why**: Bash has no closures, lambdas, or block arguments. You cannot pass
"a block of rendering code" to a function. The begin/end pattern lets overlay
authors write natural imperative code between the markers:

```bash
widget_card_begin "Git Status"
  layout_kv "Branch" "main"
  layout_kv "Status" "clean"
  widget_commit_list 5
widget_card_end
```

The alternative would be to pass all content as arguments, which is awkward:

```bash
widget_card "Git Status" \
  "kv:Branch:main" \
  "kv:Status:clean" \
  "commits:5"
```

**Trade-off**: The begin/end pattern relies on mutable global state
(`_CARD_START_ROW`, `_CARD_COL`, `_CARD_WIDTH`). This makes nested cards
fragile and side-by-side cards complex (as seen in the demo's wide-layout
code, which manually saves/restores card state). It also means
`widget_card_end()` draws the side borders *retroactively*, going back to
paint `|` characters on rows that were already rendered.

### Pipe-to-while Subshell Issues and the <<< Pattern

**Decision**: Capture multi-line data into a variable first, then use
`while IFS= read -r line; do ... done <<< "$variable"`.

**Why**: In bash, piping into `while` creates a subshell:

```bash
# BROKEN: modifications to _LAYOUT_CURSOR_ROW are lost
echo "$data" | while read -r line; do
    layout_advance 1  # modifies _LAYOUT_CURSOR_ROW in subshell
done
# _LAYOUT_CURSOR_ROW is unchanged here!
```

The `<<<` (here-string) approach runs the `while` loop in the current shell,
so global state mutations (cursor position, card tracking) are preserved.

**Trade-off**: This requires pre-fetching all data into variables before
rendering, which is why the demo's `render()` function has a block of
variable assignments before the layout code. This is slightly less readable
than inline piping but is essential for correctness.

### Footer at Fixed Bottom vs Flow-based

**Decision**: The footer is always drawn at `SCREEN_ROWS - 1`, regardless
of how much content was rendered above.

**Why**: A fixed footer provides a consistent anchor for key hints and
metadata. Users always know where to look for the controls. If the footer
were flow-based (rendered after content), it would jump around as content
length changed, and it would not appear at all if content overflowed the
screen.

**Trade-off**: If content grows too tall, it will overlap with the footer.
There is no scrolling or overflow detection. The framework relies on overlay
authors to keep content within `SCREEN_INNER_ROWS`. The responsive
breakpoints (`layout_breakpoint()`) help by allowing overlays to show less
content on smaller screens.

---

## Part 3: Future Directions

### Performance

#### Lazy Rendering

**What**: Only render widgets that are visible within the current viewport.
Skip rendering for widgets that would be drawn below the bottom of the screen
or above the top (if scrolling is implemented).

**Why**: Currently, `render()` draws everything top to bottom, even if the
bottom half will never be seen because it exceeds `SCREEN_ROWS`. For overlays
with many cards or long data lists, this wastes time generating escape
sequences that are immediately overwritten or ignored.

**How**: Track a "viewport" range (top_row, bottom_row). Each widget checks
whether its row range intersects the viewport before drawing. The layout
system already tracks `_LAYOUT_CURSOR_ROW`, so the check is cheap:

```bash
layout_in_viewport() {
    [[ $_LAYOUT_CURSOR_ROW -ge $_VIEWPORT_TOP ]] &&
    [[ $_LAYOUT_CURSOR_ROW -le $_VIEWPORT_BOTTOM ]]
}
```

Widgets that are above the viewport still need to advance the cursor (to keep
positioning correct) but skip the actual printf calls.

#### Dirty Regions

**What**: Track which regions of the screen have changed since the last render
and only redraw those regions.

**Why**: Full-screen redraws cause flickering, especially on slower terminals
or over SSH. If only one key-value pair changed (e.g., the time in the
subtitle), redrawing the entire screen is wasteful.

**How**: Maintain a "previous frame buffer" -- an array of strings, one per
row, representing what was last drawn. On re-render, compare each row's new
content to the buffer. Only emit escape sequences for rows that differ. This
is essentially the approach used by ncurses.

```bash
_FRAME_BUFFER=()  # indexed by row number

_draw_if_changed() {
    local row=$1 content="$2"
    if [[ "${_FRAME_BUFFER[$row]:-}" != "$content" ]]; then
        cursor_to "$row" 1
        printf '%s' "$content"
        _FRAME_BUFFER[$row]="$content"
    fi
}
```

The main challenge is that current widgets write directly to stdout with
printf. A frame buffer approach would require widgets to write to an
intermediate buffer first, then diff and flush. This is a significant
architectural change.

#### Double Buffering

**What**: Render the entire frame to a string buffer in memory, then write
it to the terminal in a single `printf` call.

**Why**: Multiple small writes to stdout can cause tearing, where the terminal
displays a partially updated frame. A single large write is atomic from the
terminal's perspective (or at least much closer to it).

**How**: Redirect all widget output to a variable during rendering, then flush:

```bash
_RENDER_BUFFER=""
_buffer_write() { _RENDER_BUFFER+="$1"; }

# During render, replace printf with buffer writes
# After render, flush:
printf '%s' "$_RENDER_BUFFER"
_RENDER_BUFFER=""
```

This pairs well with dirty regions: buffer the new frame, diff against the
old frame, then emit only the changed regions in a single write.

### Layout

#### Flexbox-like System

**What**: A layout engine that automatically distributes available space among
child elements based on flex weights, minimum sizes, and growth factors.

**Why**: The current two-column layout in `demo.sh` is manual and brittle. The
overlay author must calculate `half = (SCREEN_INNER_COLS - 3) / 2`, manually
position columns, and manually balance their heights. A flexbox system would
make multi-column and responsive layouts declarative.

**How**: Define a layout DSL:

```bash
layout_flex_row  # start a horizontal flex container
  layout_flex_item 1  # flex-grow: 1
    widget_card_begin "Git" "$_FLEX_WIDTH"
    ...
    widget_card_end
  layout_flex_end_item

  layout_flex_item 1  # flex-grow: 1
    widget_card_begin "System" "$_FLEX_WIDTH"
    ...
    widget_card_end
  layout_flex_end_item
layout_flex_end_row
```

The `layout_flex_row` function calculates available width, divides it according
to flex weights, and sets `_FLEX_WIDTH` for each item. Items can specify
`min_width` to trigger wrapping to a new row when the terminal is too narrow.

This could also enable `flex_col` (vertical) and nested flex containers.

#### Constraint-based Layout

**What**: Define relationships between elements ("card B starts where card A
ends", "sidebar is 30% of width, minimum 20 columns") and let a solver
determine positions.

**Why**: Complex layouts with dependent sizing (e.g., a sidebar whose content
determines its width, which then determines the main area width) are hard to
express with the current cursor-tracking approach.

**How**: A simple constraint solver that runs before rendering:

1. Collect all constraints (min/max sizes, relative positions, proportions)
2. Resolve them in topological order (no circular dependencies)
3. Set concrete row/col/width/height for each region
4. Render into the resolved regions

This is more complex than flexbox but enables layouts that flexbox cannot
express, like "this card's height matches that card's height" (which the demo
currently does manually with the column-balancing code).

#### Auto-sizing Cards

**What**: Cards that automatically determine their height based on content,
without the overlay needing to pre-calculate or pad.

**Why**: The begin/end pattern draws side borders retroactively, which works,
but the overlay author has no way to know a card's final height before
rendering it. This makes it hard to do things like "place card B immediately
after card A" when A's height depends on dynamic data.

**How**: A two-pass approach:

1. **Measure pass**: Render card content to `/dev/null` (or a counter), tracking
   how many rows were used.
2. **Draw pass**: Now knowing the height, draw the card with proper borders.

Alternatively, buffer card content and draw it all at once in `card_end()`,
which already knows the start row and current row.

### Widgets

#### Rich Text Input

**What**: A text input widget with cursor movement, editing, and
auto-completion.

**Why**: Currently, overlays can only read single keystrokes. There is no way
to accept typed text (e.g., a search query, a command, a file path).

**How**: A `widget_input()` function that:

- Draws an input box at the current layout position
- Shows a cursor (blinking underline or block)
- Handles character insertion, backspace, left/right cursor movement
- Supports enter to submit and escape to cancel
- Maintains a buffer string and cursor position
- Optionally shows completions in a dropdown below the input

```bash
widget_input "Search:" 40 "my_callback"
# Renders:  Search: [__________________|          ]
# Calls my_callback with the entered text on Enter
```

The main challenge is that `input_read_key()` is designed for single-key
dispatch, not text accumulation. The input widget would need to temporarily
take over the input loop or run its own nested loop.

#### Scrollable Panes

**What**: A region of the screen that can scroll independently, showing a
viewport into content that is taller than the available space.

**Why**: Long lists (git logs, file trees, search results) cannot currently
be scrolled. They either get truncated or overflow into the footer.

**How**: A `widget_scrollpane` that:

- Allocates a fixed-height region on screen
- Maintains a scroll offset and total content height
- Renders only the visible portion of the content
- Shows scroll indicators (arrows, scrollbar) on the right edge
- Binds up/down keys (or j/k) for scrolling when focused

```bash
widget_scrollpane_begin "Files" 10  # 10 visible rows
  for file in "${files[@]}"; do
    layout_print "$file"
  done
widget_scrollpane_end
```

This requires the content cursor to be virtual (tracking total height) and
only emitting output for rows within the pane's viewport.

#### Tab Navigation

**What**: A tabbed interface where different views share the same screen
area, switched by tab key or number keys.

**Why**: Complex overlays (like the demo with its git log and sessions
sub-views) currently replace the entire screen for each view. Tabs would
allow fluid navigation between related views while maintaining context
(header, footer, shared state).

**How**: A `widget_tabs` system:

```bash
widget_tabs_begin "git" "system" "sessions"
  # Only the active tab's content renders
  case "$_ACTIVE_TAB" in
    git)      render_git_tab ;;
    system)   render_system_tab ;;
    sessions) render_sessions_tab ;;
  esac
widget_tabs_end
```

The tab bar renders at the top of the tab area, with the active tab
highlighted. Number keys (1/2/3) or tab/shift-tab switch between tabs.

#### Tree Views

**What**: A collapsible tree widget for hierarchical data (directory listings,
git trees, configuration structures).

**Why**: Hierarchical data is common in developer tools. A tree view with
expand/collapse, indentation guides, and keyboard navigation would be a
powerful widget.

**How**: Track tree state (which nodes are expanded) and render with
indentation:

```
  ▼ src/
  │ ▼ lib/
  │ │   colors.sh
  │ │   drawing.sh
  │ │ ► data.sh      (collapsed, has children)
  │   overlay.sh
  ► config/           (collapsed)
    README.md
```

Each node stores: label, depth, has_children, is_expanded, is_selected.
Up/down navigates, enter/right expands, left collapses.

#### File Browser

**What**: A full file browser widget combining tree view, preview pane,
and file operations.

**Why**: Many developer workflows involve navigating files. A file browser
overlay could replace the common pattern of typing `ls`, `cd`, `cat` in
a terminal.

**How**: Combine tree view (left pane) with a preview pane (right pane)
that shows file contents, git status, and file metadata. Support operations
like open-in-editor, copy path, git blame.

### Theming

#### Runtime Theme Editor

**What**: An interactive overlay that lets users preview and customize
themes in real time.

**Why**: Currently, changing themes requires editing code or cycling through
presets. A visual editor would let users tune colors to their preference
and see the result immediately.

**How**: An overlay that:

1. Shows a preview of all widget types (banner, cards, status indicators,
   text styles)
2. Lists all THEME_ variables with their current hex values
3. Lets users navigate to a color, press enter, and type a new hex value
4. Applies the change immediately and re-renders the preview
5. Exports the customized theme as a `.sh` file to `config/themes/`

#### 256-color Fallbacks

**What**: Automatically downgrade truecolor themes to 256-color equivalents
when the terminal does not support truecolor.

**Why**: Not all terminals support 24-bit color. The current approach is
binary: use truecolor if available, or fall back to the `minimal` theme
with basic ANSI colors. A 256-color fallback would preserve most of the
visual richness.

**How**: For each hex color in a theme, find the nearest 256-color palette
entry. The 256-color palette has a regular structure (16 system + 216 color
cube + 24 grays) that can be searched with arithmetic:

```bash
hex_to_256() {
    local hex="${1#\#}"
    local r=$((0x${hex:0:2})) g=$((0x${hex:2:2})) b=$((0x${hex:4:2}))
    # Map to 6x6x6 cube (indices 16-231)
    local ri=$(( (r - 55) / 40 )) gi=$(( (g - 55) / 40 )) bi=$(( (b - 55) / 40 ))
    [[ $ri -lt 0 ]] && ri=0; [[ $ri -gt 5 ]] && ri=5
    [[ $gi -lt 0 ]] && gi=0; [[ $gi -gt 5 ]] && gi=5
    [[ $bi -lt 0 ]] && bi=0; [[ $bi -gt 5 ]] && bi=5
    echo $(( 16 + 36*ri + 6*gi + bi ))
}
```

Apply this mapping in `_apply_theme()` when `has_truecolor` returns false
but `has_256color` returns true.

#### Auto-detect Terminal Capabilities

**What**: Probe the terminal for its actual capabilities rather than relying
on environment variables.

**Why**: `$COLORTERM` and `$TERM` are not always set correctly. Some
terminals support truecolor but do not advertise it. A probe can determine
the truth.

**How**: Use the `DECRQSS` or `OSC 4` escape sequences to query the terminal
directly. Send a truecolor escape, query the cursor position or cell color,
and check if the terminal processed it correctly. This is fragile and terminal-
specific but can improve the detection rate.

A simpler approach: maintain a list of known terminal emulators and their
capabilities (iTerm2, Kitty, Alacritty, WezTerm all support truecolor;
Apple Terminal does not). Check `$TERM_PROGRAM` and `$LC_TERMINAL`.

### Integration

#### Deeper Tmux Integration

**What**: Use tmux hooks, status bar, and format strings to tightly integrate
overlays with the tmux workflow.

**Why**: Currently, overlays are isolated popups. Deeper integration could:

- Show overlay-sourced data in the tmux status bar
- Trigger overlays from tmux hooks (e.g., on session switch)
- Synchronize theme colors with tmux's pane borders and status bar

**How**:

- **Status bar**: Use `tmux set-option -g status-right` to display data
  from the bus state directory. A background process reads
  `state/git_branch` and updates the status bar format.
- **Hooks**: Register `tmux set-hook after-select-pane` to emit a bus event
  when the user switches panes. The overlay can refresh its data in response.
- **Theme sync**: When loading a theme, also run
  `tmux set-option pane-border-style "fg=$THEME_HEX_BORDER"` to match.

#### iTerm2 Python API

**What**: Use iTerm2's Python API to access advanced features like custom
UI elements, session monitoring, and image display.

**Why**: iTerm2 (the most popular macOS terminal) exposes a rich Python API
that can create status bar components, trigger actions on events, and
manipulate sessions programmatically.

**How**: Ship a Python companion script that:

1. Connects to iTerm2 via its API
2. Reads from the bus state directory
3. Updates iTerm2 status bar components with overlay data
4. Listens for iTerm2 events (window focus, profile change) and writes
   bus commands

This would need to be optional (graceful degradation if iTerm2 or Python
is not available).

#### Kitty Graphics Protocol

**What**: Display inline images, charts, and rich graphics using Kitty's
graphics protocol (also supported by WezTerm and others).

**Why**: Terminal UIs are limited to Unicode characters. With the Kitty
graphics protocol, overlays could display actual images: graphs, logos,
QR codes, architecture diagrams.

**How**: The protocol uses base64-encoded image data sent through escape
sequences:

```bash
display_image() {
    local file="$1" row=$2 col=$3
    local data
    data=$(base64 < "$file")
    cursor_to "$row" "$col"
    printf '\033_Ga=T,f=100,t=d;%s\033\\' "$data"
}
```

This could enable:

- Sparkline charts rendered as actual pixel graphics
- Repository avatars next to branch names
- Architecture diagrams in help overlays

### Communication

#### WebSocket Bridge

**What**: A lightweight WebSocket server that bridges the bus to web clients.

**Why**: This would allow web dashboards, browser extensions, or mobile apps
to interact with overlays in real time. A remote developer could see the
same overlay data in a browser.

**How**: A small Node.js or Python script that:

1. Watches the bus directory for new events (via `fswatch` or polling)
2. Broadcasts events to connected WebSocket clients as JSON
3. Receives commands from clients and writes them to the bus commands directory

```json
// Event sent to WebSocket client
{"type": "event", "name": "select", "payload": "item_3", "time": "2026-04-05T12:00:00Z"}

// Command received from WebSocket client
{"type": "command", "name": "refresh", "payload": "git_data"}
```

#### HTTP API

**What**: A REST API for querying overlay state and sending commands.

**Why**: HTTP is the lingua franca of integration. An HTTP API would let
any tool (curl, scripts, CI systems, Slack bots) interact with overlays.

**How**: A minimal HTTP server (using bash's `/dev/tcp` or a small Python
script) that maps:

- `GET /state/:key` -> `bus_state_get(key)`
- `PUT /state/:key` -> `bus_state_set(key, body)`
- `POST /events` -> `bus_emit(name, payload)`
- `GET /events/latest` -> read `events/_latest`
- `POST /commands` -> `bus_send_command(name, payload)`

#### Structured JSON Events

**What**: Replace the current plain-text event format with JSON.

**Why**: The current format (`event: name\ntime: ...\npayload: ...`) is
ad-hoc and hard to parse reliably, especially for multi-line payloads. JSON
is universally parseable and supports nested data.

**How**: Emit events as JSON:

```bash
bus_emit_json() {
    local name="$1" payload="$2"
    printf '{"event":"%s","time":"%s","pid":%d,"payload":%s}\n' \
        "$name" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$$" "$payload" \
        > "$file"
}
```

This requires a JSON serializer in bash (or relying on `jq` as an optional
dependency). For simple string payloads, manual escaping suffices. For
complex data, `jq` would be the right choice.

### Testing

#### Automated Visual Regression Testing

**What**: Capture the rendered output of overlays and compare against
golden files to detect unintended visual changes.

**Why**: UI changes are hard to review in code diffs. A visual regression
test captures what the user actually sees and flags changes.

**How**: Leverage the existing `tools/screenshot.sh preview` command:

1. For each overlay and theme combination, render in a detached tmux
   session with fixed dimensions (e.g., 80x24).
2. Capture the plain-text output (ANSI-stripped).
3. Compare against a committed golden file using `diff`.
4. If they differ, show the diff and optionally update the golden file.

```bash
# test_visual.sh
for overlay in overlays/*.sh; do
    for theme in catppuccin tokyonight; do
        actual=$(tools/screenshot.sh preview "$overlay" --theme "$theme" --format text)
        golden="tests/golden/$(basename $overlay .sh)_${theme}.txt"
        if ! diff -q "$actual" "$golden" > /dev/null; then
            echo "FAIL: $(basename $overlay) / $theme"
            diff "$actual" "$golden"
        fi
    done
done
```

#### CI Screenshots

**What**: Run visual tests in CI (GitHub Actions) using a headless tmux
session.

**Why**: Visual regressions should be caught before merge, not after.

**How**: GitHub Actions runners have tmux available. The test script can:

1. Start a tmux server in the CI environment
2. Run `tools/screenshot.sh preview` for each test case
3. Compare outputs against golden files
4. Upload any diffs as CI artifacts for human review
5. Optionally use an image-diff tool if screenshot images are used

### Packaging

#### Homebrew Formula

**What**: A Homebrew tap and formula for one-command installation.

**Why**: `brew install tmux-claude-overlay` is the standard way to
distribute CLI tools on macOS.

**How**: Create a Homebrew tap repository (`homebrew-tmux-claude-overlay`)
with a formula that:

- Downloads the release tarball
- Installs scripts to `$(brew --prefix)/share/tmux-claude-overlay/`
- Creates a symlink from `bin/overlay` to `$(brew --prefix)/bin/overlay`
- Declares tmux as a dependency

```ruby
class TmuxClaudeOverlay < Formula
  desc "Beautiful terminal overlay framework for tmux"
  homepage "https://github.com/user/tmux-claude-overlay"
  url "https://github.com/user/tmux-claude-overlay/archive/v1.0.0.tar.gz"
  sha256 "..."
  depends_on "tmux"

  def install
    prefix.install Dir["*"]
    bin.install_symlink prefix/"bin/overlay"
  end
end
```

#### TPM (Tmux Plugin Manager) Support

**What**: Package as a tmux plugin installable via TPM.

**Why**: TPM is the standard plugin manager for tmux. Users add a line to
`.tmux.conf` and press `prefix + I` to install.

**How**: Add a `tmux-claude-overlay.tmux` file at the repo root that:

1. Sets up key bindings (e.g., `prefix + O` to launch the overlay)
2. Adds the overlay command to PATH
3. Optionally integrates with the tmux status bar

```bash
# tmux-claude-overlay.tmux
CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
tmux bind-key O run-shell "$CURRENT_DIR/bin/overlay launch demo"
```

### Accessibility

#### Screen Reader Support

**What**: Emit semantic information that screen readers can interpret.

**Why**: Terminal overlays are inherently visual. Screen readers see a wall
of ANSI escape sequences. Providing structured output makes the tool usable
for visually impaired developers.

**How**: Two approaches:

1. **OSC annotations**: Some terminals support OSC (Operating System Command)
   sequences that attach metadata to screen regions. Use these to label
   widgets, indicate focus, and describe status indicators.

2. **Alternative output mode**: When `$ACCESSIBILITY=1`, skip visual
   rendering and instead output structured text to stderr:

   ```
   [section] Git Status
   [kv] Branch: main
   [kv] Status: clean (3 files changed)
   [section] Recent Commits
   [list] abc1234 Fix login timeout
   [list] def5678 Add user settings page
   ```

#### High Contrast Modes

**What**: Themes designed for high contrast, following WCAG guidelines for
color contrast ratios.

**Why**: Some users need higher contrast than typical dark themes provide.
The `minimal` theme is a start but it uses dim text which reduces contrast.

**How**: Create `highcontrast_dark` and `highcontrast_light` themes that:

- Use only black and white backgrounds
- Use bold, high-saturation foreground colors
- Ensure all text/background combinations exceed 7:1 contrast ratio
- Use underlines and bold instead of color alone to convey meaning
- Double-check with a contrast ratio calculator

### Multi-pane

#### Coordinated Overlays Across Panes

**What**: Multiple overlays running in different tmux panes that communicate
and coordinate through the bus.

**Why**: Complex workflows might benefit from a master-detail layout: one
pane shows a list, another shows details for the selected item. Or a
monitoring dashboard where each pane shows a different data source.

**How**: Extend the bus to support named channels:

```bash
# Pane 1: file list
bus_init "$SHARED_BUS_DIR"
bus_emit "select" "src/lib/colors.sh"

# Pane 2: file preview (watches for select events)
bus_init "$SHARED_BUS_DIR"
bus_watch_events handle_event
```

Both overlays share the same bus directory (passed via environment variable).
Events from one overlay trigger updates in the other.

A `layout_multi_pane` helper could automate the tmux pane creation:

```bash
overlay_multi_pane \
    "left:file_browser" \
    "right:file_preview" \
    --layout "50%,50%"
```

#### Master-Detail Layouts

**What**: A pattern where selecting an item in a list pane shows its details
in an adjacent pane.

**Why**: This is a common and powerful UI pattern (email clients, file
managers, API explorers) that works well in wide terminals.

**How**: Build on coordinated overlays with a standard protocol:

1. Master emits `{"event":"select","payload":{"id":"item_3","type":"commit"}}`
2. Detail receives the event and renders the appropriate detail view
3. Bus state tracks the current selection for persistence across refreshes

### Animation

#### Smooth Transitions

**What**: Animated transitions between views (fade, slide, crossfade).

**Why**: Abrupt screen clears and redraws are jarring. Even simple transitions
make the UI feel more polished and help users track context changes.

**How**: Terminal animation is done through rapid frame updates:

```bash
# Slide transition: new content slides in from the right
transition_slide_left() {
    local old_frame="$1" new_frame="$2" duration=0.2
    local steps=5
    local cols=$SCREEN_COLS
    for ((step=0; step<steps; step++)); do
        local offset=$(( cols - cols * step / steps ))
        # Render old frame shifted left, new frame from right
        render_offset "$old_frame" $((-offset)) "$new_frame" $((cols - offset))
        sleep $(echo "$duration / $steps" | bc -l)
    done
}
```

**Practical concern**: Bash is slow. Animation at 30+ fps requires either:

- Very few changed cells per frame (dirty region rendering helps)
- A compiled helper program for the frame rendering
- Accepting a lower frame rate (10 fps can still look decent for simple
  transitions)

#### Fade In/Out

**What**: Widgets appear by fading from dim to full brightness.

**Why**: Fade effects draw attention to new content and feel premium.

**How**: Use dim/normal/bold attributes to simulate brightness levels:

```bash
fade_in() {
    local text="$1" row=$2 col=$3
    cursor_to "$row" "$col"
    printf '%s%s%s' "$DIM$DIM" "$text" "$RST"  # Very dim
    sleep 0.05
    cursor_to "$row" "$col"
    printf '%s%s%s' "$DIM" "$text" "$RST"      # Dim
    sleep 0.05
    cursor_to "$row" "$col"
    printf '%s%s%s' "" "$text" "$RST"           # Normal
}
```

For truecolor terminals, true alpha-like fading is possible by interpolating
the text color from the background color to the target color over several
steps.

#### Slide Effects

**What**: Cards or sections slide into view from an edge.

**Why**: Directional movement reinforces spatial mental models -- "the
sessions view is to the right of the main view."

**How**: Render the widget at progressively increasing offsets:

```bash
slide_in_from_right() {
    local render_fn="$1" steps=8
    for ((step=steps; step>=0; step--)); do
        local offset=$((step * 5))
        _LAYOUT_CURSOR_COL=$((_LAYOUT_CURSOR_COL + offset))
        "$render_fn"
        _LAYOUT_CURSOR_COL=$((_LAYOUT_CURSOR_COL - offset))
        sleep 0.03
    done
}
```

### Data

#### Live-updating Data Streams

**What**: Data providers that continuously push new data to the overlay,
triggering incremental re-renders.

**Why**: Some data changes frequently (CPU load, network traffic, log
output). Polling on every keypress is not enough; true live updates
require a background data source.

**How**: A background process writes to bus state on a timer:

```bash
# Background data feeder (runs in a separate process)
while true; do
    bus_state_set "cpu_load" "$(sysctl -n vm.loadavg | awk '{print $2}')"
    bus_state_set "net_bytes" "$(netstat -ib | awk '/en0/{print $7}')"
    bus_send_command "data_updated" "cpu_load,net_bytes"
    sleep 2
done &
```

The overlay polls for commands in the input loop (with a short timeout on
`read`) and re-renders the relevant widgets when data changes.

#### Polling Providers

**What**: Data providers that automatically refresh at configurable
intervals.

**Why**: Manual refresh (`r` key) is fine for low-frequency data but tedious
for monitoring scenarios.

**How**: Extend `data_fetch()` with a TTL (time-to-live):

```bash
data_fetch_ttl() {
    local key="$1" ttl="$2"; shift 2
    local file=$(_cache_key_file "$key")
    local age_file="${file}.ts"
    if [[ -f "$file" && -f "$age_file" ]]; then
        local cached_time=$(cat "$age_file")
        local now=$(date +%s)
        if [[ $((now - cached_time)) -lt $ttl ]]; then
            cat "$file"
            return 0
        fi
    fi
    local result=$("$@" 2>/dev/null) || result=""
    printf '%s' "$result" > "$file"
    date +%s > "$age_file"
    echo "$result"
}
```

#### Webhook Receivers

**What**: Accept HTTP webhooks from CI systems, deployment tools, or
monitoring services, and display the data in overlays.

**Why**: Many developer events originate outside the terminal (GitHub Actions
completing, deployment finishing, alerts firing). Bringing these into the
overlay keeps the developer in their flow.

**How**: A minimal webhook listener (using `nc` or Python) that:

1. Listens on a local port
2. Parses incoming JSON payloads
3. Writes events to the bus

```bash
# Minimal webhook receiver
while true; do
    request=$(nc -l 8080)
    payload=$(echo "$request" | tail -1)  # body is after headers
    bus_send_command "webhook" "$payload"
done &
```

The overlay registers a command handler:

```bash
handle_webhook() {
    local payload="$1"
    bus_state_set "ci_status" "$(echo "$payload" | jq -r '.status')"
    render
}
```

### Security

#### Sandboxed Overlays

**What**: Run overlay scripts in a restricted environment that limits what
they can access.

**Why**: If the overlay ecosystem grows to include community-contributed
overlays, users need assurance that an overlay cannot read their SSH keys,
modify files, or exfiltrate data.

**How**: Multiple layers:

1. **Read-only filesystem**: Mount the overlay script and framework read-only
   using macOS sandbox profiles or Linux namespaces.

2. **Network restrictions**: Prevent overlays from making network connections
   unless explicitly allowed.

3. **Limited commands**: Restrict which external commands an overlay can run
   via `PATH` manipulation:

   ```bash
   sandbox_overlay() {
       local script="$1"
       local safe_path="/usr/bin/git:/usr/bin/tmux:/usr/bin/date"
       PATH="$safe_path" bash --restricted "$script"
   }
   ```

4. **Capability declarations**: Overlays declare what they need in a metadata
   header:

   ```bash
   # overlay-capabilities: git, tmux, network
   ```

   The launcher checks capabilities and prompts the user for approval.

#### Permission Model for Bus Commands

**What**: Control which processes can send commands to an overlay's bus.

**Why**: The bus directory is world-readable by default (it is in /tmp).
Any process could send commands to manipulate the overlay.

**How**:

1. **Restrictive permissions**: Create the bus directory with `0700`
   permissions so only the same user can access it.

2. **Shared secret**: On bus_init, generate a random token and write it
   to the bus directory. Command senders must include the token:

   ```bash
   bus_send_command_auth() {
       local token=$(cat "$OVERLAY_BUS_DIR/.token")
       local name="$1" payload="$2"
       cat > "$file" <<EOF
   command: ${name}
   token: ${token}
   payload: ${payload}
   EOF
   }
   ```

   The overlay verifies the token before processing commands.

3. **Signed events**: For the paranoid, HMAC-sign events and commands
   using a pre-shared key. This prevents tampering even if the bus
   directory is readable.

---

## Appendix: Source File Reference

| File                   | Lines | Purpose                                          |
|------------------------|-------|--------------------------------------------------|
| `bin/overlay`          | 133   | CLI entry point, tmux popup launcher             |
| `lib/overlay.sh`      | 116   | Framework loader, lifecycle management           |
| `lib/colors.sh`       | 174   | ANSI codes, hex/rgb/gradient, detection          |
| `lib/theme.sh`        | 209   | 5 built-in themes, semantic color mapping        |
| `lib/drawing.sh`      | 313   | Box chars, cursor, lines, boxes, text, progress  |
| `lib/layout.sh`       | 247   | Dimensions, grid, sections, header/footer, WINCH |
| `lib/data.sh`         | 246   | File cache, git/sys/tmux providers, custom data  |
| `lib/input.sh`        | 329   | Key bindings, read loop, menu, help modal        |
| `lib/widgets.sh`      | 488   | Banner, cards, tables, badges, sparklines, DSL   |
| `lib/bus.sh`          | 291   | IPC: events, commands, state, discovery          |
| `overlays/demo.sh`    | 289   | Demo dashboard overlay                           |
| `config/defaults.sh`  | 22    | Default configuration values                     |
| `tools/screenshot.sh` | 273   | Capture, preview, compare, gallery               |
