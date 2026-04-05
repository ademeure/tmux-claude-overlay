# Screenshot an Overlay

Capture screenshots of an overlay for review.

**Arguments:** `$ARGUMENTS` — `<name> [--all-themes]`

## Instructions

1. Parse `$ARGUMENTS` to get the overlay name and whether to render all themes.

2. **Single theme capture:**
   ```bash
   cd /Users/arun/tmux-claude-overlay
   tmux new-session -d -s _ss -x 110 -y 40 \
     "OVERLAY_THEME=catppuccin OVERLAY_ROOT=/Users/arun/tmux-claude-overlay \
      bash overlays/<name>.sh 2>/dev/null; sleep 999"
   sleep 3
   tmux capture-pane -t _ss -p > screenshots/iterations/<name>_$(date +%Y%m%d_%H%M%S).txt
   tmux kill-session -t _ss
   ```

3. **All themes** (if `--all-themes`):
   ```bash
   for theme in catppuccin tokyonight dracula nord minimal; do
     tmux new-session -d -s "_ss_${theme}" -x 110 -y 40 \
       "OVERLAY_THEME=$theme OVERLAY_ROOT=/Users/arun/tmux-claude-overlay \
        bash overlays/<name>.sh 2>/dev/null; sleep 999"
   done
   sleep 3
   for theme in catppuccin tokyonight dracula nord minimal; do
     tmux capture-pane -t "_ss_${theme}" -p > screenshots/iterations/<name>_${theme}.txt
     tmux kill-session -t "_ss_${theme}"
   done
   ```

4. Read and display the captured text output.

5. Also test at narrow width (80x30) if the user wants thorough testing.
