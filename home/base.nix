# Home Manager profile for every machine: shell, prompt, git and the
# command-line helpers. Nothing graphical — that is home/desktop.
{
  config,
  lib,
  pkgs,
  osConfig,
  ...
}:
let
  # Where this repository is checked out (set once in modules/base.nix).
  repository = osConfig.programs.nh.flake;

  # atuin 18.19 names both its nushell keybindings "atuin", which nushell now
  # warns about at every startup. Upstream renamed the up-arrow one to
  # atuin_up_arrow (atuin PR #3975, in 18.21); this applies the same rename to
  # the generated init until nixpkgs ships 18.21, replacing the home-manager
  # atuin nushell integration (same generation, plus the rename).
  atuinNushellConfig =
    pkgs.runCommand "atuin-nushell-config.nu"
      {
        nativeBuildInputs = [ pkgs.writableTmpDirAsHomeHook ];
      }
      ''
        ${lib.getExe config.programs.atuin.package} init nu \
          | awk '/name: atuin$/ { count++; if (count == 2) sub(/name: atuin$/, "name: atuin_up_arrow") } { print }' \
          > "$out"
      '';
in
{
  home.username = "justin";
  home.homeDirectory = "/home/justin";
  home.stateVersion = "25.11";

  home.sessionVariables = {
    EDITOR = "nvim";
  };

  programs.git = {
    enable = true;
    settings = {
      user = {
        name = "ComradeJustin";
        email = "chinese2000ping@gmail.com";
      };
      init.defaultBranch = "main";
    };
  };

  programs.nushell = {
    enable = true;
    # nushell is the login shell, so it has to load home.sessionVariables
    # itself (EDITOR and the desktop ones); nothing else does.
    loadSessionVariables = true;
    shellAliases = {
      ctf = "nix develop ${repository}#ctf";
      rust = "nix develop ${repository}#rust";
      cuda = "nix develop ${repository}#cuda";
      rebuild = "${repository}/scripts/rebuild.sh";
      update = "${repository}/scripts/update.sh";
      wake = "${repository}/scripts/wake.sh";
      infra-status = "${repository}/scripts/status.sh";
    };
    extraConfig = ''
      $env.config = {
        show_banner: false,
        completions: {
          case_sensitive: false # case-sensitive completions
          quick: false        # set to false to prevent auto-selecting completions
          partial: false        # set to false to prevent partial filling of the prompt
          algorithm: "fuzzy"    # prefix or fuzzy
          external: {
            # set to false to prevent nushell looking into $env.PATH to find more suggestions
            enable: true
            # set to lower can improve completion performance at the cost of omitting some options
            max_results: 100
          }
        }
      }

      source ${atuinNushellConfig}
    '';
  };

  programs.direnv = {
    enable = true;
    enableNushellIntegration = true;
    nix-direnv.enable = true;
  };

  programs.atuin = {
    enable = true;
    # Replaced by atuinNushellConfig above (see the keybinding-name note).
    enableNushellIntegration = false;
  };

  programs.carapace.enable = true;
  programs.carapace.enableNushellIntegration = true;

  programs.starship.enable = true;
}
