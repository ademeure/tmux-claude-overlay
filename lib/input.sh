#!/usr/bin/env bash
# tmux-claude-overlay: Input / interaction system
# Key binding registry, navigation, menu selection, modal support.
# Compatible with bash 3.2+ (no associative arrays).
# Source after colors.sh, theme.sh, drawing.sh.

# ============================================================
# Key binding registry (eval-based for bash 3.2)
# ============================================================

# We store bindings as _BIND_<sanitized_key>_callback and _BIND_<sanitized_key>_desc
# Key order is tracked in a regular array.
_INPUT_KEY_ORDER=()

# Sanitize key name for use as variable suffix
_key_san() {
    local key="$1"
    case "$key" in
        escape) echo "escape" ;;
        enter)  echo "enter" ;;
        tab)    echo "tab" ;;
        space)  echo "space" ;;
        up)     echo "up" ;;
        down)   echo "down" ;;
        left)   echo "left" ;;
        right)  echo "right" ;;
        backspace) echo "backspace" ;;
        "?")    echo "question" ;;
        *)      echo "$key" ;;
    esac
}

# Register a key binding.
# Usage: input_bind "key" "callback_function" "description"
input_bind() {
    local key="$1" callback="$2" desc="${3:-}"
    local san
    san=$(_key_san "$key")
    eval "_BIND_${san}_callback=\"$callback\""
    eval "_BIND_${san}_desc=\"$desc\""
    eval "_BIND_${san}_key=\"$key\""
    _INPUT_KEY_ORDER[${#_INPUT_KEY_ORDER[@]}]="$key"
}

# Remove a key binding
input_unbind() {
    local san
    san=$(_key_san "$1")
    eval "unset _BIND_${san}_callback"
    eval "unset _BIND_${san}_desc"
    eval "unset _BIND_${san}_key"
}

# Clear all bindings
input_clear() {
    for key in "${_INPUT_KEY_ORDER[@]}"; do
        input_unbind "$key"
    done
    _INPUT_KEY_ORDER=()
}

# Get callback for a key (returns empty string if not bound)
_input_get_callback() {
    local san
    san=$(_key_san "$1")
    eval "echo \"\${_BIND_${san}_callback:-}\""
}

# Get description for a key
_input_get_desc() {
    local san
    san=$(_key_san "$1")
    eval "echo \"\${_BIND_${san}_desc:-}\""
}

# ============================================================
# Key reading
# ============================================================

_INPUT_KEY=""

input_read_key() {
    local timeout="${1:-}"
    local read_args=(-rsn1)
    [[ -n "$timeout" ]] && read_args=(-rsn1 -t "$timeout")

    _INPUT_KEY=""
    local char
    if ! IFS= read "${read_args[@]}" char; then
        return 1  # timeout
    fi

    # Handle escape sequences
    if [[ "$char" == $'\e' ]]; then
        local seq
        if IFS= read -rsn1 -t 0.1 seq; then
            if [[ "$seq" == "[" ]]; then
                IFS= read -rsn1 -t 0.1 seq
                case "$seq" in
                    A) _INPUT_KEY="up" ;;
                    B) _INPUT_KEY="down" ;;
                    C) _INPUT_KEY="right" ;;
                    D) _INPUT_KEY="left" ;;
                    H) _INPUT_KEY="home" ;;
                    F) _INPUT_KEY="end" ;;
                    *) _INPUT_KEY="unknown" ;;
                esac
            else
                _INPUT_KEY="escape"
            fi
        else
            _INPUT_KEY="escape"
        fi
    elif [[ "$char" == "" ]]; then
        _INPUT_KEY="enter"
    elif [[ "$char" == $'\t' ]]; then
        _INPUT_KEY="tab"
    elif [[ "$char" == " " ]]; then
        _INPUT_KEY="space"
    elif [[ "$char" == $'\177' ]]; then
        _INPUT_KEY="backspace"
    else
        _INPUT_KEY="$char"
    fi
    return 0
}

# ============================================================
# Input loop
# ============================================================

_INPUT_RUNNING=0

input_loop() {
    _INPUT_RUNNING=1
    while [[ $_INPUT_RUNNING -eq 1 ]]; do
        input_read_key || continue

        local key="$_INPUT_KEY"
        local callback
        callback=$(_input_get_callback "$key")

        # Try lowercase if no exact match
        if [[ -z "$callback" ]]; then
            local lower
            lower=$(echo "$key" | tr '[:upper:]' '[:lower:]')
            callback=$(_input_get_callback "$lower")
        fi

        if [[ -n "$callback" ]]; then
            "$callback"
        fi
    done
}

input_stop() {
    _INPUT_RUNNING=0
}

# ============================================================
# Menu / list selection
# ============================================================

_MENU_ITEMS=()
_MENU_SELECTED=0
_MENU_SCROLL_OFFSET=0
_MENU_VISIBLE_COUNT=0
_MENU_ROW=0
_MENU_COL=0
_MENU_WIDTH=0
_MENU_CALLBACK=""

menu_init() {
    _MENU_ROW="$1"
    _MENU_COL="$2"
    _MENU_VISIBLE_COUNT="$3"
    _MENU_WIDTH="$4"
    _MENU_CALLBACK="$5"
    _MENU_ITEMS=()
    _MENU_SELECTED=0
    _MENU_SCROLL_OFFSET=0
}

menu_add_item() {
    _MENU_ITEMS[${#_MENU_ITEMS[@]}]="$1"
}

menu_selected_index() { echo "$_MENU_SELECTED"; }
menu_selected_item() { echo "${_MENU_ITEMS[$_MENU_SELECTED]}"; }

menu_render() {
    local total=${#_MENU_ITEMS[@]}
    local visible=$_MENU_VISIBLE_COUNT
    [[ $visible -gt $total ]] && visible=$total

    # Adjust scroll
    if [[ $_MENU_SELECTED -lt $_MENU_SCROLL_OFFSET ]]; then
        _MENU_SCROLL_OFFSET=$_MENU_SELECTED
    elif [[ $_MENU_SELECTED -ge $((_MENU_SCROLL_OFFSET + visible)) ]]; then
        _MENU_SCROLL_OFFSET=$((_MENU_SELECTED - visible + 1))
    fi

    local i
    for ((i=0; i<visible; i++)); do
        local idx=$((_MENU_SCROLL_OFFSET + i))
        local row=$((_MENU_ROW + i))
        local item="${_MENU_ITEMS[$idx]}"

        cursor_to "$row" "$_MENU_COL"
        if [[ $idx -eq $_MENU_SELECTED ]]; then
            printf '%s%s ❯ %-*s %s' \
                "$C_BG_HIGHLIGHT" "$C_PRIMARY" \
                "$((_MENU_WIDTH - 4))" "$item" "$RST"
        else
            printf '%s   %-*s %s' \
                "$C_TEXT" \
                "$((_MENU_WIDTH - 4))" "$item" "$RST"
        fi
        erase_eol
    done

    # Scroll indicators
    if [[ $_MENU_SCROLL_OFFSET -gt 0 ]]; then
        cursor_to $((_MENU_ROW - 1)) $((_MENU_COL + _MENU_WIDTH / 2))
        printf '%s▲%s' "$C_MUTED" "$RST"
    fi
    if [[ $((_MENU_SCROLL_OFFSET + visible)) -lt $total ]]; then
        cursor_to $((_MENU_ROW + visible)) $((_MENU_COL + _MENU_WIDTH / 2))
        printf '%s▼%s' "$C_MUTED" "$RST"
    fi
}

menu_up() {
    [[ $_MENU_SELECTED -gt 0 ]] && _MENU_SELECTED=$((_MENU_SELECTED - 1))
    menu_render
}

menu_down() {
    local total=${#_MENU_ITEMS[@]}
    [[ $_MENU_SELECTED -lt $((total - 1)) ]] && _MENU_SELECTED=$((_MENU_SELECTED + 1))
    menu_render
}

menu_select() {
    if [[ -n "$_MENU_CALLBACK" ]]; then
        "$_MENU_CALLBACK" "$_MENU_SELECTED" "${_MENU_ITEMS[$_MENU_SELECTED]}"
    fi
}

menu_bind_keys() {
    input_bind "up"    "menu_up"     "Move up"
    input_bind "down"  "menu_down"   "Move down"
    input_bind "k"     "menu_up"     "Move up"
    input_bind "j"     "menu_down"   "Move down"
    input_bind "enter" "menu_select" "Select"
}

# ============================================================
# Help overlay
# ============================================================

input_show_help() {
    local rows cols
    rows=$(tput lines); cols=$(tput cols)

    local count=0
    local seen=""
    for key in "${_INPUT_KEY_ORDER[@]}"; do
        local desc
        desc=$(_input_get_desc "$key")
        [[ -z "$desc" ]] && continue
        # Dedup
        case ",$seen," in *",$key,"*) continue ;; esac
        seen="${seen},${key}"
        count=$((count + 1))
    done

    local box_h=$((count + 6))
    local box_w=40
    [[ $box_h -gt $((rows - 4)) ]] && box_h=$((rows - 4))
    local start_row=$(( (rows - box_h) / 2 ))
    local start_col=$(( (cols - box_w) / 2 ))

    draw_titled_box "$start_row" "$start_col" "$box_h" "$box_w" "Key Bindings" "$C_BORDER" "$C_HEADING"

    local r=$((start_row + 2))
    seen=""
    for key in "${_INPUT_KEY_ORDER[@]}"; do
        local desc
        desc=$(_input_get_desc "$key")
        [[ -z "$desc" ]] && continue
        case ",$seen," in *",$key,"*) continue ;; esac
        seen="${seen},${key}"
        [[ $r -ge $((start_row + box_h - 2)) ]] && break

        cursor_to "$r" $((start_col + 2))
        printf '%s%s[%s]%s %-*s' \
            "$C_BG_SURFACE" "$C_ACCENT" "$key" "$RST" \
            "$((box_w - 8))" ""
        cursor_to "$r" $((start_col + 8))
        printf '%s%s%s' "$C_TEXT" "$desc" "$RST"
        r=$((r + 1))
    done

    cursor_to $((start_row + box_h - 2)) $((start_col + 2))
    printf '%s%sPress any key to close%s' "$C_BG_SURFACE" "$C_MUTED" "$RST"

    read -rsn1
}

# ============================================================
# Footer hint string from bindings
# ============================================================

input_hint_string() {
    local hints=""
    local seen=""
    for key in "${_INPUT_KEY_ORDER[@]}"; do
        local desc
        desc=$(_input_get_desc "$key")
        [[ -z "$desc" ]] && continue
        case ",$seen," in *",$key,"*) continue ;; esac
        seen="${seen},${key}"
        [[ -n "$hints" ]] && hints="$hints  "
        hints="${hints}[${key}]${desc}"
    done
    echo "$hints"
}
