{ pkgs ? import <nixpkgs> {} }:
pkgs.mkShell {
  packages = with pkgs; [
    (python3.withPackages (ps: with ps; [
      pwntools
      ropper
    ]))
    gdb
    checksec
    file
    binutils
    zsh
    zsh-autosuggestions
    zsh-fzf-tab
    fzf
    atuin
    starship
    carapace
  ];

  shellHook = ''
    export ZDOTDIR=$(mktemp -d)
    cat > "$ZDOTDIR/.zshrc" <<ZRC
      autoload -Uz compinit && compinit
      source ${pkgs.zsh-fzf-tab}/share/fzf-tab/fzf-tab.plugin.zsh
      source ${pkgs.zsh-autosuggestions}/share/zsh-autosuggestions/zsh-autosuggestions.zsh
      eval "\$(starship init zsh)"
      eval "\$(atuin init zsh)"
      eval "\$(carapace _carapace zsh)"
    ZRC
    export SHELL=${pkgs.zsh}/bin/zsh
    exec zsh
  '';
}
