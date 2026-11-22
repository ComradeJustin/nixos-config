# fcitx5 input method with Japanese (mozc).
{ pkgs, ... }:
{
  i18n.inputMethod = {
    enable = true;
    type = "fcitx5";
    # Apps reach fcitx through the compositor, the way Wayland means them
    # to, and GTK_IM_MODULE and QT_IM_MODULE are left unset. With those set
    # as well, fcitx warns at every login that they should not be.
    fcitx5.waylandFrontend = true;
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
}
