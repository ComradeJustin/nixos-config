{ config, lib, pkgs, ... }:
let
  cfg = config.modules.status-reporter;

  # Build the status generation script from config
  statusScript = pkgs.writeShellScript "status-report" ''
    set -euo pipefail

    OUT_DIR="/var/lib/status"
    OUT="$OUT_DIR/status.json"
    mkdir -p "$OUT_DIR"

    # ── System info ──
    hostname=$(${pkgs.hostname}/bin/hostname)

    # Uptime
    uptime_raw=$(cut -d' ' -f1 /proc/uptime | cut -d. -f1)
    days=$((uptime_raw / 86400))
    hours=$(( (uptime_raw % 86400) / 3600 ))
    mins=$(( (uptime_raw % 3600) / 60 ))
    if [ "$days" -gt 0 ]; then
      uptime="''${days}d ''${hours}h"
    else
      uptime="''${hours}h ''${mins}m"
    fi

    # Load
    load=$(cut -d' ' -f1 /proc/loadavg)

    # Memory
    mem_total=$(${pkgs.gawk}/bin/awk '/MemTotal/ {print $2}' /proc/meminfo)
    mem_avail=$(${pkgs.gawk}/bin/awk '/MemAvailable/ {print $2}' /proc/meminfo)
    mem_used=$(( (mem_total - mem_avail) * 100 / mem_total ))
    mem_display=$(${pkgs.gawk}/bin/awk "BEGIN {printf \"%.1f/%.1fG\", ($mem_total - $mem_avail) / 1048576, $mem_total / 1048576}")

    # Disk
    disk=$(${pkgs.coreutils}/bin/df -h / | ${pkgs.gawk}/bin/awk 'NR==2 {print $3 "/" $2}')

    # ── Services ──
    services="{"
    first=true
    for svc in ${lib.concatStringsSep " " (map (s: ''"${s}"'') cfg.services)}; do
      if [ "$first" = true ]; then first=false; else services="$services,"; fi
      if ${pkgs.systemd}/bin/systemctl is-active --quiet "$svc" 2>/dev/null; then
        services="$services \"$svc\": true"
      else
        services="$services \"$svc\": false"
      fi
    done
    services="$services }"

    # ── Tailscale nodes ──
    nodes=$(${pkgs.tailscale}/bin/tailscale status 2>/dev/null | ${pkgs.gnugrep}/bin/grep -v '^#' | ${pkgs.gnugrep}/bin/grep -v '^$' | ${pkgs.coreutils}/bin/wc -l || true)
    nodes="''${nodes:-0}"

    # ── NixOS generation ──
    generation=$(readlink /nix/var/nix/profiles/system | ${pkgs.gnused}/bin/sed 's/.*-\([0-9]*\)-link/\1/')

    ts=$(date +%s)

    cat > "$OUT" <<ENDJSON
    {
      "hostname": "$hostname",
      "uptime": "$uptime",
      "load": "$load",
      "memory": "$mem_display",
      "memory_pct": $mem_used,
      "disk": "$disk",
      "nodes": $nodes,
      "generation": $generation,
      "timestamp": $ts,
      "services": $services
    }
    ENDJSON
  '';

  # Minimal HTTP server to serve the status file
  serverScript = pkgs.writeShellScript "status-server" ''
    cd /var/lib/status
    exec ${pkgs.python3}/bin/python3 -m http.server ${toString cfg.port} --bind 0.0.0.0
  '';
in
{
  options.modules.status-reporter = {
    enable = lib.mkEnableOption "System status reporter";

    port = lib.mkOption {
      type = lib.types.port;
      default = 9200;
      description = "Port to serve status JSON on";
    };

    interval = lib.mkOption {
      type = lib.types.str;
      default = "30s";
      description = "How often to regenerate status";
    };

    services = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Systemd service names to monitor (without .service suffix)";
    };
  };

  config = lib.mkIf cfg.enable {
    # Directory
    systemd.tmpfiles.rules = [
      "d /var/lib/status 0755 root root -"
    ];

    # Timer to regenerate status
    systemd.services.status-report = {
      description = "Generate system status JSON";
      serviceConfig = {
        Type = "oneshot";
        ExecStart = statusScript;
      };
    };

    systemd.timers.status-report = {
      description = "Regenerate status JSON periodically";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnBootSec = "10s";
        OnUnitActiveSec = cfg.interval;
      };
    };

    # HTTP server to expose status
    systemd.services.status-server = {
      description = "Status reporter HTTP server";
      after = [ "network.target" "status-report.service" ];
      wants = [ "status-report.service" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        ExecStart = serverScript;
        Restart = "always";
        DynamicUser = true;
        ReadOnlyPaths = [ "/var/lib/status" ];
      };
    };

    # Status reporter: reachable via trusted interfaces only
  };
}
