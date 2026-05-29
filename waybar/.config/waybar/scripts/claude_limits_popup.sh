#!/usr/bin/env bash
#
# Toggle a small eww popup with every Claude plan-usage bucket, anchored under
# the waybar click position. Reuses cl_data + cl-row from claude-limits-widget;
# position is supplied dynamically via `eww open --pos --anchor`.
#
set -euo pipefail

WIN="claude-limits-menu"
POPUP_W=320

cursor="$(hyprctl cursorpos 2>/dev/null || echo '20, 0')"
cx="${cursor%%,*}"; cx="${cx// /}"
[[ "$cx" =~ ^[0-9]+$ ]] || cx=20

# Center the popup horizontally on the click.
left=$(( cx - POPUP_W / 2 ))

# Clamp so the window stays fully on-screen (logical width = phys / scale).
mon_logical_w="$(hyprctl monitors -j 2>/dev/null \
  | jq -r 'first | (.width / .scale) | floor' 2>/dev/null || echo 1600)"
max_left=$(( mon_logical_w - POPUP_W - 8 ))
(( left > max_left )) && left=$max_left
(( left < 8 ))        && left=8

# Idempotent: spawns daemon if not running.
eww daemon >/dev/null 2>&1 || true

eww open --toggle "$WIN" \
  --arg "menu_x=${left}px" \
  >/dev/null 2>&1 || true
