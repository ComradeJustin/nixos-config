#!/usr/bin/env bash
set -euo pipefail

# ── Device MAC registry ──
# Add new WoL devices here: "hostname|mac"
declare -A DEVICES=(
    ["nixpc"]="7c:10:c9:47:3e:57"
)

RELAY_HOST="nixpc"

HOST="${1:-}"

if [[ -z "$HOST" ]]; then
    echo "Usage: $0 <hostname>"
    echo ""
    echo "Available devices:"
    for dev in "${!DEVICES[@]}"; do
        echo "  $dev (${DEVICES[$dev]})"
    done
    exit 1
fi

MAC="${DEVICES[$HOST]:-}"
if [[ -z "$MAC" ]]; then
    echo "Error: unknown device '$HOST'"
    echo "Available: ${!DEVICES[*]}"
    exit 1
fi

if ping -c1 -W1 192.168.1.1 &>/dev/null; then
    echo "On LAN — sending WoL packet directly to $HOST ($MAC)..."
    wol "$MAC"
else
    echo "Off LAN — relaying WoL via $RELAY_HOST over Tailscale..."
    ssh "$RELAY_HOST" "wol $MAC"
fi

echo "Waiting for $HOST to come online..."
for i in $(seq 1 30); do
    if ping -c1 -W1 "$HOST" &>/dev/null; then
        echo "$HOST is online! (took ~${i}s)"
        exit 0
    fi
    sleep 1
done

echo "Timed out after 30s — $HOST may still be booting or WoL may not be enabled in BIOS."
