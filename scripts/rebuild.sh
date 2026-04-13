#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FLAKE_DIR="$(dirname "$SCRIPT_DIR")"

# ── Colors ──
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
DIM='\033[2m'
RESET='\033[0m'

info()  { echo -e "${CYAN}::${RESET} $*"; }
warn()  { echo -e "${YELLOW}::${RESET} $*"; }
err()   { echo -e "${RED}::${RESET} $*"; }
ok()    { echo -e "${GREEN}::${RESET} $*"; }

HOST="${1:-}"
TARGET="${2:-}"

# Auto-pull latest config if working tree is clean
if git -C "${FLAKE_DIR}" diff --quiet && git -C "${FLAKE_DIR}" diff --cached --quiet; then
    info "Pulling latest config..."
    git -C "${FLAKE_DIR}" pull --rebase --quiet 2>/dev/null || warn "git pull failed (offline or no remote?)"
else
    warn "Working tree is dirty — skipping git pull"
fi

# Auto-detect remote hosts from hosts/servers/ directory
REMOTE_HOSTS=""
if [[ -d "${FLAKE_DIR}/hosts/servers" ]]; then
    REMOTE_HOSTS=$(find "${FLAKE_DIR}/hosts/servers" -mindepth 1 -maxdepth 1 -type d ! -name '_template' -printf '%f ')
fi

if [[ -z "$HOST" ]]; then
    echo -e "${BOLD}Usage:${RESET} $0 <hostname> [user@ip]"
    echo ""
    echo -e "  ${BOLD}Local hosts:${RESET}  nixpc, nixlaptop"
    echo -e "  ${BOLD}Remote hosts:${RESET} ${REMOTE_HOSTS:-none}"
    echo ""
    echo -e "  ${DIM}For remote hosts, optionally pass the target address:${RESET}"
    echo -e "    $0 home-core justin@192.168.1.158"
    echo -e "    $0 nixpc root@nixpc"
    echo -e "  ${DIM}If omitted for server hosts, uses justin@<hostname> (Tailscale/DNS)${RESET}"
    echo -e "  ${DIM}For local hosts, pass a target to deploy remotely instead of locally${RESET}"
    exit 1
fi

# Check if any remote builders are reachable
BUILDERS_ONLINE=0
if [[ -f /etc/nix/machines ]]; then
    info "Checking remote builders..."
    while IFS=' ' read -r uri _rest; do
        [[ -z "$uri" ]] && continue
        builder_host="${uri#*@}"
        if sudo ssh -o ConnectTimeout=2 -o BatchMode=yes "root@${builder_host}" true 2>/dev/null; then
            BUILDERS_ONLINE=$((BUILDERS_ONLINE + 1))
            ok "  ${builder_host} ${GREEN}online${RESET}"
        else
            warn "  ${builder_host} ${RED}offline${RESET}"
        fi
    done < /etc/nix/machines
fi

MAX_JOBS_FLAG=""
if [[ "$BUILDERS_ONLINE" -gt 0 ]]; then
    ok "Found ${BOLD}${BUILDERS_ONLINE}${RESET}${GREEN} remote builder(s)${RESET} — limiting local jobs to 4"
    MAX_JOBS_FLAG="--max-jobs 4"
else
    warn "No remote builders reachable — using all local cores"
fi

if [[ -n "$TARGET" ]] || echo "$REMOTE_HOSTS" | grep -qw "$HOST"; then
    REMOTE_TARGET="${TARGET:-justin@${HOST}}"
    info "Building locally and deploying ${BOLD}${HOST}${RESET} to ${CYAN}${REMOTE_TARGET}${RESET}..."

    # Use root via Tailscale SSH to avoid sudo password prompts
    REMOTE_HOST="${REMOTE_TARGET#*@}"
    set -o pipefail
    nixos-rebuild switch --flake "${FLAKE_DIR}#${HOST}" \
        --target-host "root@${REMOTE_HOST}" \
        ${MAX_JOBS_FLAG} |& nom

    ok "Deploy to ${BOLD}${HOST}${RESET} complete!"
else
    info "Building ${BOLD}${HOST}${RESET} locally..."
    if [[ -n "$MAX_JOBS_FLAG" ]]; then
        nh os switch "${FLAKE_DIR}" -H "${HOST}" --ask -- ${MAX_JOBS_FLAG}
    else
        nh os switch "${FLAKE_DIR}" -H "${HOST}" --ask
    fi
fi || { err "Build failed!"; exit 1; }

# Sign and push current system to harmonia cache if reachable
CACHE_KEY="/var/lib/harmonia-cache-key.pem"
if [[ -f "$CACHE_KEY" ]] && sudo ssh -o ConnectTimeout=2 -o BatchMode=yes root@home-core true 2>/dev/null; then
    SYSTEM_PATH="$(readlink -f /run/current-system)"
    info "Signing and pushing build to harmonia cache..."
    nix store sign --key-file "$CACHE_KEY" --recursive "$SYSTEM_PATH" 2>/dev/null
    nix copy --to ssh-ng://root@home-core "$SYSTEM_PATH" 2>/dev/null \
        && ok "Cache updated!" \
        || warn "Cache push failed (non-fatal)"
fi
