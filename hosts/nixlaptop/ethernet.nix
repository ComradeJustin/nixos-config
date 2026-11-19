# Workarounds for the laptop's Intel I219-LM ethernet port, which fails to
# negotiate a link on some switch ports.
{ pkgs, ... }:
let
  interface = "enp0s31f6";
in
{
  # Disable EEE — prevents link on switches with poor EEE support
  services.udev.extraRules = ''
    ACTION=="add", SUBSYSTEM=="net", KERNEL=="${interface}", RUN+="${pkgs.ethtool}/bin/ethtool --set-eee ${interface} eee off"
  '';

  # Auto-downshift to 100Mbps if gigabit negotiation fails on certain switch ports
  systemd.services."e1000e-negotiation-retry" = {
    description = "Fallback to 100Mbps if gigabit negotiation fails";
    wantedBy = [ "network.target" ];
    after = [ "network-pre.target" ];
    serviceConfig = {
      Type = "simple";
      RemainAfterExit = true;
      ExecStart = pkgs.writeShellScript "e1000e-retry" ''
        IFACE=${interface}
        sleep 3

        LINK=$(${pkgs.ethtool}/bin/ethtool $IFACE | ${pkgs.gawk}/bin/awk '/Link detected/{print $3}')
        if [ "$LINK" = "yes" ]; then exit 0; fi

        # No link — try forcing 100Mbps to distinguish negotiation failure from unplugged cable
        ${pkgs.ethtool}/bin/ethtool -s $IFACE speed 100 duplex full autoneg off
        ${pkgs.iproute2}/bin/ip link set $IFACE up
        sleep 2

        LINK=$(${pkgs.ethtool}/bin/ethtool $IFACE | ${pkgs.gawk}/bin/awk '/Link detected/{print $3}')
        if [ "$LINK" = "yes" ]; then
          ${pkgs.util-linux}/bin/logger "e1000e: gigabit negotiation failed, staying at 100Mbps"
        else
          # Cable is unplugged — restore autoneg
          ${pkgs.ethtool}/bin/ethtool -s $IFACE autoneg on
          ${pkgs.util-linux}/bin/logger "e1000e: no carrier at 100Mbps either, cable likely unplugged"
        fi
      '';
    };
  };

  # Manual versions of the same switch, as shell commands.
  home-manager.users.justin.programs.nushell.extraConfig = ''
    # Force 100Mbps when a switch port has auto-negotiation issues
    def eth-downshift [] {
      sudo ethtool -s ${interface} speed 100 duplex full autoneg off
    }

    # Restore gigabit auto-negotiation
    def eth-gigabit [] {
      sudo ethtool -s ${interface} speed 1000 duplex full autoneg on
    }
  '';
}
