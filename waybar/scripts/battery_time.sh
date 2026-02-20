#!/usr/bin/env bash

BAT="/sys/class/power_supply/BAT0"

# Read battery info
CURRENT=$(cat "$BAT/charge_now" 2>/dev/null || cat "$BAT/energy_now")
FULL=$(cat "$BAT/charge_full" 2>/dev/null || cat "$BAT/energy_full")
STATUS=$(cat "$BAT/status")
CURRENT_NOW=$(cat "$BAT/current_now" 2>/dev/null || cat "$BAT/power_now")

# Avoid division by zero
if [[ "$CURRENT_NOW" -eq 0 ]]; then
    echo "..."
    exit 0
fi

# Calculate remaining time in minutes
if [[ "$STATUS" == "Discharging" ]]; then
    TOTAL_MIN=$(( CURRENT * 60 / CURRENT_NOW ))
elif [[ "$STATUS" == "Charging" ]]; then
    REMAINING=$(( FULL - CURRENT ))
    TOTAL_MIN=$(( REMAINING * 60 / CURRENT_NOW ))
else
    echo "full"
    exit 0
fi

# Convert to hours and minutes
H=$(( TOTAL_MIN / 60 ))
M=$(( TOTAL_MIN % 60 ))

# Output
if [[ "$H" -gt 0 ]]; then
    echo "${H}h ${M}m"
else
    echo "${M}m"
fi

