#!/usr/bin/env bash
# Clipboard history picker — self-contained (cliphist + rofi + wl-clipboard).
# No hyde-shell required.
#
# Requires the clipboard watcher to be running (added to hyprland.conf):
#   wl-paste --type text  --watch cliphist store
#   wl-paste --type image --watch cliphist store
#
# Usage:
#   cliphist.sh        show history, copy selection
#   cliphist.sh -c     same (kept for the SUPER+V keybind)
#   cliphist.sh -d     delete an entry from history
#   cliphist.sh -w     wipe the whole history

set -euo pipefail

# Toggle: if rofi is already open, close it and bail.
pkill -x rofi && exit 0

theme="$HOME/.config/rofi/clipboard.rasi"
rofi_theme=(); [[ -f $theme ]] && rofi_theme=(-theme "$theme")

case "${1:-}" in
    -d|--delete)
        cliphist list \
            | rofi -dmenu -i -p "Delete" "${rofi_theme[@]}" \
            | cliphist delete
        ;;
    -w|--wipe)
        choice=$(printf 'No\nYes' | rofi -dmenu -i -p "Wipe clipboard history?" "${rofi_theme[@]}")
        [[ $choice == "Yes" ]] && { cliphist wipe; notify-send "Clipboard" "History wiped"; }
        ;;
    *)  # -c / --copy / no args: pick an entry and copy it
        cliphist list \
            | rofi -dmenu -i -p "Clipboard" "${rofi_theme[@]}" \
            | cliphist decode \
            | wl-copy
        ;;
esac
