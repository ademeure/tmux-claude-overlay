# Launch an Overlay

Launch an existing overlay in a tmux popup.

**Arguments:** `$ARGUMENTS` — `<name> [--theme <theme>] [--width <w>] [--height <h>]`

## Instructions

1. Parse `$ARGUMENTS` to extract the overlay name and any options.

2. Check if the overlay exists at `/Users/arun/tmux-claude-overlay/overlays/<name>.sh`.
   If not, list available overlays with `bin/overlay list` and offer to create one.

3. Launch with:
   ```bash
   /Users/arun/tmux-claude-overlay/bin/overlay launch <name> [options]
   ```

   Available options:
   - `--theme <name>` — catppuccin, tokyonight, dracula, nord, minimal
   - `--width <w>` — popup width (default: 80%, can be % or columns)
   - `--height <h>` — popup height (default: 80%, can be % or rows)
   - `--style <s>` — box style: round, sharp, double, heavy

4. If no theme specified, default to catppuccin.
