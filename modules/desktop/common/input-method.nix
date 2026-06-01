{ config, lib, pkgs, ... }:
{
  options.modules.inputMethod.enable = lib.mkEnableOption "fcitx5 input method with Japanese support";

  config = lib.mkIf config.modules.inputMethod.enable {
    i18n.inputMethod = {
      enable = true;
      type = "fcitx5";
      fcitx5.addons = with pkgs; [
        fcitx5-mozc
        fcitx5-gtk
      ];
    };

    # System-wide default fcitx5 profile: keyboard-us + mozc.
    # Users can override in ~/.config/fcitx5/profile via fcitx5-configtool.
    environment.etc."xdg/fcitx5/profile".text = ''
      [Groups/0]
      Name=Default
      Default Layout=us
      DefaultIM=keyboard-us

      [Groups/0/Items/0]
      Name=keyboard-us
      Layout=

      [Groups/0/Items/1]
      Name=mozc
      Layout=

      [GroupOrder]
      0=Default
    '';

    # System-wide fcitx5 hotkeys: switch IM with Alt+Space instead of Ctrl+Space.
    environment.etc."xdg/fcitx5/config".text = ''
      [Hotkey]
      EnumerateWithTriggerKeys=True
      TriggerKeys=
      TriggerKeys[0]=Alt+space
    '';
  };
}
