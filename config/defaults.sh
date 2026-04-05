#!/usr/bin/env bash
# tmux-claude-overlay: Default configuration
# Override these in your overlay or via environment variables.

# Theme
export OVERLAY_THEME="${OVERLAY_THEME:-catppuccin}"

# Box drawing style: round, sharp, double, heavy
export OVERLAY_STYLE="${OVERLAY_STYLE:-round}"

# Popup dimensions (used by bin/overlay launch)
export OVERLAY_WIDTH="${OVERLAY_WIDTH:-80%}"
export OVERLAY_HEIGHT="${OVERLAY_HEIGHT:-80%}"

# Layout padding
export LAYOUT_PAD_TOP="${LAYOUT_PAD_TOP:-1}"
export LAYOUT_PAD_BOTTOM="${LAYOUT_PAD_BOTTOM:-1}"
export LAYOUT_PAD_LEFT="${LAYOUT_PAD_LEFT:-2}"
export LAYOUT_PAD_RIGHT="${LAYOUT_PAD_RIGHT:-2}"

# Screenshot directory
export OVERLAY_SCREENSHOT_DIR="${OVERLAY_SCREENSHOT_DIR:-screenshots}"
