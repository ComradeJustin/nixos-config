#!/usr/bin/env bash
# Build and deploy a host of this flake.
#   rebuild.sh <host>            build + switch this machine
#   rebuild.sh <host> <user@ip>  build locally, deploy to a remote machine
# First deploy to a fresh machine: use root@<ip> so the store copy is trusted.
set -eo pipefail

FLAKE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOST="${1:-}"
TARGET="${2:-}"

if [[ -z "$HOST" ]]; then
    echo "Usage: $0 <host> [user@ip]"
    echo "Hosts: nixpc, nixlaptop"
    echo "With user@ip, builds locally and deploys to that machine."
    exit 1
fi

# Pull latest config if the working tree is clean. --ff-only never rewrites
# local commits: if the branches have diverged it fails and leaves the
# checkout as it was.
if git -C "$FLAKE_DIR" diff --quiet && git -C "$FLAKE_DIR" diff --cached --quiet; then
    git -C "$FLAKE_DIR" pull --ff-only --quiet \
        || echo "git pull failed (see the error above) — building current checkout"
else
    echo "Working tree is dirty — skipping git pull"
fi

# If nixpc is reachable, use it for this rebuild: cap local jobs so nix offloads
# builds to it, and add its binary cache (which is off by default so that other
# nix commands never wait on it).
# /etc/nix/machines only exists on build clients, so this is a no-op on nixpc itself.
EXTRA_ARGS=()
if [[ -s /etc/nix/machines ]] && timeout 5 ssh -o ConnectTimeout=3 -o BatchMode=yes justin@nixpc true 2>/dev/null; then
    echo "nixpc is online — using its cache and capping local jobs at 4"
    EXTRA_ARGS=(-- --max-jobs 4 --option extra-substituters http://nixpc:5000)
fi

# --- Telling the desktop shell how the rebuild is going ---
# The shell shows a rebuild in its bar and in its monitor (configs/shell).
# shell-call hands it a request. A machine without the shell has no such
# command, and none of this does anything there.

# report <phase> <made> <total> <names of what is being built now>
report() {
    if command -v shell-call >/dev/null; then
        shell-call build "$1" "$2" "$3" "$4" >/dev/null 2>&1 || true
    fi
}

# The store paths this rebuild has to make, one per line: what will be built
# and what will be fetched. nix is asked without building anything.
planned_paths() {
    local plan
    plan="$(nix build "$FLAKE_DIR#nixosConfigurations.$HOST.config.system.build.toplevel" --dry-run "${EXTRA_ARGS[@]:1}" 2>&1)" || return 0
    # What will be built is listed as .drv files: ask what each one produces.
    grep -oE '/nix/store/[^ ]+\.drv$' <<<"$plan" | xargs -r nix-store --query --outputs || true
    # What will be fetched is listed as the paths themselves.
    grep -oE '/nix/store/[^ ]+$' <<<"$plan" | grep -v '\.drv$' || true
}

# Report how far the rebuild has got, every two seconds, until stopped. A
# path exists once it has been made, and a path that is being built has a
# ".lock" file beside it.
watch_progress() {
    local made now path name phase
    while true; do
        made=0
        now=""
        for path in "${PLANNED[@]}"; do
            if [[ -e "$path" ]]; then
                made=$((made + 1))
            elif [[ -e "$path.lock" ]]; then
                # The name without the folder and the hash in front of it.
                name="${path##*/}"
                now="$now, ${name#*-}"
            fi
        done
        phase="building"
        # Everything is made: what is left is your answer and the switch.
        if ((made == ${#PLANNED[@]})); then
            phase="finishing"
        fi
        report "$phase" "$made" "${#PLANNED[@]}" "${now#, }"
        sleep 2
    done
}

# However this script ends, stop reporting and tell the shell how it went.
finish() {
    local status=$?
    kill "$WATCHER" 2>/dev/null || true
    if ((status == 0)); then
        report done 0 0 ""
    else
        report failed 0 0 ""
    fi
}

report evaluating 0 0 ""
mapfile -t PLANNED < <(planned_paths)
watch_progress &
WATCHER=$!
trap finish EXIT

if [[ -n "$TARGET" ]]; then
    echo "Building ${HOST} and deploying to ${TARGET}..."
    nh os switch "$FLAKE_DIR" -H "$HOST" --ask --target-host "$TARGET" "${EXTRA_ARGS[@]}"
else
    echo "Building ${HOST} locally..."
    nh os switch "$FLAKE_DIR" -H "$HOST" --ask "${EXTRA_ARGS[@]}"
    kill "$WATCHER" 2>/dev/null || true

    # Push the new system to nixpc's store so other machines can substitute it.
    # Harmonia signs paths as it serves them, so nothing is signed here.
    # /etc/nix/machines only exists on build clients, so nixpc skips this.
    if [[ -s /etc/nix/machines ]] && timeout 5 ssh -o ConnectTimeout=3 -o BatchMode=yes justin@nixpc true 2>/dev/null; then
        SYSTEM_PATH="$(readlink -f /run/current-system)"
        echo "Pushing build to the nixpc cache..."
        report copying 0 0 ""
        nix copy --no-check-sigs --to ssh-ng://justin@nixpc "$SYSTEM_PATH" \
            || echo "Cache push failed (non-fatal)"
    fi
fi
