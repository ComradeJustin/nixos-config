#!/usr/bin/env bash
set -euo pipefail

# ── Network device registry ──
# Add new devices here: "hostname|role|services"
# Roles: client, builder, cache, multi
# Services: comma-separated list
DEVICES=(
    "nixlaptop|client|"
    "nixpc|builder|"
    "home-core|cache|harmonia,exit-node,nginx,docker"
)

# ── Colors ──
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
DIM='\033[2m'
RESET='\033[0m'

# ── Gather tailscale status ──
declare -A TS_STATUS TS_IP
while IFS= read -r line; do
    # Skip header line
    [[ "$line" == *"# "* ]] && continue
    ip=$(echo "$line" | awk '{print $1}')
    hostname=$(echo "$line" | awk '{print $2}')
    status=$(echo "$line" | awk '{print $5}')
    [[ -z "$hostname" ]] && continue
    TS_STATUS["$hostname"]="$status"
    TS_IP["$hostname"]="$ip"
done < <(tailscale status 2>/dev/null || true)

# ── Gather builder info from /etc/nix/machines ──
declare -A BUILDER_JOBS BUILDER_SPEED
if [[ -f /etc/nix/machines ]]; then
    while IFS=' ' read -r uri system _ maxjobs speed _rest; do
        [[ -z "$uri" ]] && continue
        host="${uri#*@}"
        BUILDER_JOBS["$host"]="$maxjobs"
        BUILDER_SPEED["$host"]="$speed"
    done < /etc/nix/machines
fi

# ── Get local hostname ──
LOCAL_HOST=$(hostname)

# ── Display ──
echo ""
echo -e "${BOLD}  Network Infrastructure${RESET}"
echo -e "${DIM}  ─────────────────────────────────────────────────────────${RESET}"
printf "  ${BOLD}%-14s %-12s %-10s %-20s %s${RESET}\n" "DEVICE" "STATUS" "ROLE" "SERVICES" "INFO"
echo -e "${DIM}  ─────────────────────────────────────────────────────────${RESET}"

for entry in "${DEVICES[@]}"; do
    IFS='|' read -r hostname role services <<< "$entry"

    # Status
    ts_state="${TS_STATUS[$hostname]:-unknown}"
    if [[ "$hostname" == "$LOCAL_HOST" ]]; then
        status="${GREEN}● local${RESET}"
    elif [[ "$ts_state" == *"active"* || "$ts_state" == *"idle"* ]]; then
        status="${GREEN}● online${RESET}"
    elif [[ "$ts_state" == *"offline"* ]]; then
        status="${RED}○ offline${RESET}"
    else
        status="${YELLOW}? unknown${RESET}"
    fi

    # Role display
    case "$role" in
        client)  role_display="${CYAN}client${RESET}" ;;
        builder) role_display="${GREEN}builder${RESET}" ;;
        cache)   role_display="${YELLOW}cache${RESET}" ;;
        multi)   role_display="${BOLD}multi${RESET}" ;;
        *)       role_display="$role" ;;
    esac

    # Services
    if [[ -n "$services" ]]; then
        svc_display="${DIM}${services}${RESET}"
    else
        svc_display="${DIM}-${RESET}"
    fi

    # Extra info
    info=""
    if [[ -n "${BUILDER_JOBS[$hostname]:-}" ]]; then
        info="${DIM}jobs:${BUILDER_JOBS[$hostname]} speed:${BUILDER_SPEED[$hostname]}${RESET}"
    fi
    ip="${TS_IP[$hostname]:-}"
    if [[ -n "$ip" ]]; then
        [[ -n "$info" ]] && info="$info "
        info="${info}${DIM}${ip}${RESET}"
    fi

    printf "  %-14s %-24b %-20b %-30b %b\n" "$hostname" "$status" "$role_display" "$svc_display" "$info"
done

echo -e "${DIM}  ─────────────────────────────────────────────────────────${RESET}"

# ── Summary ──
online=0
builders_up=0
for entry in "${DEVICES[@]}"; do
    IFS='|' read -r hostname role services <<< "$entry"
    ts_state="${TS_STATUS[$hostname]:-unknown}"
    if [[ "$hostname" == "$LOCAL_HOST" || "$ts_state" == *"active"* || "$ts_state" == *"idle"* ]]; then
        online=$((online + 1))
    fi
    if [[ "$role" == "builder" || "$role" == "multi" ]]; then
        if [[ "$hostname" == "$LOCAL_HOST" || "$ts_state" == *"active"* || "$ts_state" == *"idle"* ]]; then
            builders_up=$((builders_up + 1))
        fi
    fi
done

echo -e "  ${BOLD}${online}/${#DEVICES[@]}${RESET} devices online, ${BOLD}${builders_up}${RESET} builder(s) available"
echo ""
