#!/usr/bin/env bash
#
# Waybar one-shot fetch of the current Claude 5-hour session.
# Reads sessionKey from ~/.config/claude-limits-widget/secret.env, hits the
# same private claude.ai usage endpoint the eww widget uses, and prints a
# JSON line: { text, tooltip, class } for a custom/claude module.
#
set -euo pipefail

CONF_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/claude-limits-widget"
SECRET_FILE="$CONF_DIR/secret.env"
CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}"
ORG_CACHE="$CACHE_DIR/claude-limits-org"
SVG_PATH="$CACHE_DIR/claude-limits-arc.svg"
BODY_CACHE="$CACHE_DIR/claude-limits-body.json"
HTTP_TIMEOUT="${HTTP_TIMEOUT:-15}"
UA="${CLAUDE_UA:-Mozilla/5.0 (X11; Linux x86_64; rv:149.0) Gecko/20100101 Firefox/149.0}"
API_BASE="https://claude.ai/api"

# VSCode-extension-style ring: transparent fill, faint track, rounded-cap arc.
TRACK_COLOR="#3c3836"   # gruvbox border
NORMAL_COLOR="#e78a4e"  # gruvbox orange
WARNING_COLOR="#d8a657" # yellow at >=75%
CRITICAL_COLOR="#ea6962" # red at >=90%

mkdir -p "$CACHE_DIR" 2>/dev/null || true

CLAUDE_SESSION_KEY=""; CLAUDE_ORG_UUID=""
# shellcheck disable=SC1090
[[ -f "$SECRET_FILE" ]] && source "$SECRET_FILE" 2>/dev/null || true

emit() { # emit <text> <tooltip> <class>
  jq -cn --arg t "$1" --arg tt "$2" --arg c "$3" \
    '{text:$t, tooltip:$tt, class:$c}'
}

write_arc_svg() { # write_arc_svg <pct> <stroke_color>
  local pct="$1" color="$2"
  local filled remaining
  # circumference of r=9 ≈ 56.5487
  filled=$(awk -v p="$pct"   'BEGIN{printf "%.4f", 56.5487 * p / 100}')
  remaining=$(awk -v p="$pct" 'BEGIN{printf "%.4f", 56.5487 * (100 - p) / 100}')
  cat > "$SVG_PATH" <<EOF
<svg xmlns="http://www.w3.org/2000/svg" width="20" height="20" viewBox="0 0 24 24">
  <circle cx="12" cy="12" r="9" fill="none" stroke="$TRACK_COLOR" stroke-width="3"/>
  <circle cx="12" cy="12" r="9" fill="none" stroke="$color" stroke-width="3"
          stroke-linecap="round"
          stroke-dasharray="$filled $remaining"
          transform="rotate(-90 12 12)"/>
</svg>
EOF
}

write_track_only_svg() {
  cat > "$SVG_PATH" <<EOF
<svg xmlns="http://www.w3.org/2000/svg" width="20" height="20" viewBox="0 0 24 24">
  <circle cx="12" cy="12" r="9" fill="none" stroke="$TRACK_COLOR" stroke-width="3"/>
</svg>
EOF
}

fmt_rel() { # ISO -> "Resets in X hr Y min"
  local r now diff h m
  r="$(date -d "$1" +%s 2>/dev/null)" || { echo ""; return; }
  now="$(date +%s)"; diff=$(( r - now )); (( diff < 0 )) && diff=0
  h=$(( diff / 3600 )); m=$(( (diff % 3600) / 60 ))
  if (( h > 0 )); then echo "Resets in ${h} hr ${m} min"; else echo "Resets in ${m} min"; fi
}

api_get() {
  curl -sS -m "$HTTP_TIMEOUT" -w $'\n%{http_code}' \
    -H "Cookie: sessionKey=${CLAUDE_SESSION_KEY}" \
    -H "Accept: */*" \
    -H "anthropic-client-platform: web_claude_ai" \
    -H "User-Agent: ${UA}" \
    "$1" 2>/dev/null
}

fail() { # fail <text> <tooltip> <class>
  write_track_only_svg
  emit "$1" "$2" "$3"
  exit 0
}

if [[ -z "${CLAUDE_SESSION_KEY:-}" ]]; then
  fail "auth" "Set sessionKey in secret.env" "error"
fi

org="${CLAUDE_ORG_UUID:-}"
[[ -z "$org" && -f "$ORG_CACHE" ]] && org="$(cat "$ORG_CACHE" 2>/dev/null || true)"
if [[ -z "$org" ]]; then
  rc=0; out="$(api_get "${API_BASE}/organizations")" || rc=$?
  if (( rc == 0 )); then
    org="$(printf '%s' "${out%$'\n'*}" | jq -r 'if type=="array" then .[0].uuid else .uuid end // empty' 2>/dev/null || true)"
    [[ -n "$org" ]] && printf '%s' "$org" > "$ORG_CACHE"
  fi
fi
[[ -z "$org" ]] && fail "off" "Connect to network first" "offline"

rc=0; out="$(api_get "${API_BASE}/organizations/${org}/usage")" || rc=$?
(( rc != 0 )) && fail "off" "Connect to network first" "offline"
code="${out##*$'\n'}"; body="${out%$'\n'*}"

case "$code" in
  200) ;;
  401|419) fail "auth" "Session expired — refresh sessionKey" "error" ;;
  403)     fail "auth" "Access denied — refresh sessionKey" "error" ;;
  000)     fail "off"  "Connect to network first" "offline" ;;
  *)       fail "err"  "claude.ai HTTP ${code}" "error" ;;
esac

printf '%s' "$body" > "$BODY_CACHE"

util="$(printf '%s' "$body"   | jq -r '.five_hour.utilization // empty')"
resets="$(printf '%s' "$body" | jq -r '.five_hour.resets_at  // empty')"

if [[ -z "$util" ]]; then
  fail "—" "No active session" "idle"
fi

pct="$(printf '%.0f' "$util")"
tooltip="$(fmt_rel "$resets")"

cls="normal"; color="$NORMAL_COLOR"
if   (( pct >= 90 )); then cls="critical"; color="$CRITICAL_COLOR"
elif (( pct >= 75 )); then cls="warning";  color="$WARNING_COLOR"
fi

write_arc_svg "$pct" "$color"
emit "${pct}%" "$tooltip" "$cls"
