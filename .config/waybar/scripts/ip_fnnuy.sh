#!/usr/bin/env bash

INTERFACE="wlp2s0"
STATE_FILE="/tmp/waybar_ip_state"
TIME_FILE="/tmp/waybar_ip_last_scroll"
RESET_DELAY=5   # seconds

now=$(date +%s)

get_current_ip() {
    ip -4 addr show "$INTERFACE" | awk '/inet / {print $2}' | cut -d/ -f1
}

ip_to_int() {
    IFS=. read -r a b c d <<< "$1"
    echo $(( (a<<24) + (b<<16) + (c<<8) + d ))
}

int_to_ip() {
    local ip=$1
    echo "$(( (ip>>24)&255 )).$(( (ip>>16)&255 )).$(( (ip>>8)&255 )).$(( ip&255 ))"
}

last_scroll=0
[[ -f "$TIME_FILE" ]] && last_scroll=$(cat "$TIME_FILE")

case "$1" in
    up|down)
        IP=$(cat "$STATE_FILE" 2>/dev/null)
        [[ -z "$IP" ]] && IP=$(get_current_ip)

        IP_INT=$(ip_to_int "$IP")
        [[ "$1" == "up" ]] && IP_INT=$((IP_INT + 1))
        [[ "$1" == "down" ]] && IP_INT=$((IP_INT - 1))

        IP=$(int_to_ip "$IP_INT")

        echo "$IP" > "$STATE_FILE"
        echo "$now" > "$TIME_FILE"
        ;;
    *)
        # Only reset if no scroll recently
        if (( now - last_scroll >= RESET_DELAY )); then
            REAL_IP=$(get_current_ip)
            [[ -n "$REAL_IP" ]] && echo "$REAL_IP" > "$STATE_FILE"
        fi
        ;;
esac

IP=$(cat "$STATE_FILE" 2>/dev/null)

[[ -z "$IP" ]] \
    && echo '{"text": ""}' \
    || echo "{\"text\": \"ip: $IP\"}"

