# Neovim, configured with nvf. This is the only Neovim installed: `nvim`,
# `vi` and `vim` all start it.
#
# Colours: on desktop machines Stylix (modules/desktop/theme.nix) themes it
# from the system palette. Machines without Stylix get the gruvbox fallback
# set below.
{ inputs, lib, ... }:
{
  imports = [ inputs.nvf.nixosModules.default ];

  programs.nvf = {
    enable = true;

    settings.vim = {
      viAlias = true;
      vimAlias = true;

      theme = {
        enable = true;
        # nvf's own defaults are also mkDefault (name "onedark", style "darker").
        # A plain mkDefault ties and the build fails on hosts without Stylix.
        # 999 beats that default (1000) and still loses to Stylix's
        # normal-priority base16 theme. "darker" is not a gruvbox style.
        name = lib.mkOverride 999 "gruvbox";
        style = lib.mkOverride 999 "dark";
      };

      # Core UI / editing
      statusline.lualine.enable = true;
      telescope.enable = true;
      autocomplete.nvim-cmp.enable = true;
      treesitter.enable = true;

      # Navigation / buffers
      filetree.neo-tree.enable = true; # <leader> file explorer
      tabline.nvimBufferline.enable = true; # buffer bar
      binds.whichKey.enable = true; # keybind popup helper
      utility.motion.flash-nvim.enable = true;

      # Git suite: gitsigns + fugitive + git-conflict + gitlinker + hunk
      git.enable = true;

      # Visual niceties
      visuals = {
        indent-blankline.enable = true;
        fidget-nvim.enable = true; # LSP progress spinner
        highlight-undo.enable = true;
      };
      ui = {
        borders.enable = true;
        colorizer.enable = true; # inline #rrggbb / color previews
      };

      # LSP + language tooling
      lsp.enable = true;
      languages = {
        enableFormat = true;
        enableTreesitter = true;

        nix.enable = true;
        bash.enable = true;
        markdown.enable = true;
        python.enable = true;
      };

      # AI assistant: CodeCompanion. Multi-provider with runtime model/provider
      # switching — nothing is stored in the Nix config. Keys are read from the
      # environment at launch, per provider:
      #   export OPENAI_API_KEY="sk-..."        # OpenAI (starting adapter below)
      #   export ANTHROPIC_API_KEY="sk-ant-..." # Claude, reachable via `ga`
      # In :CodeCompanionChat, edit the model in the header to change it, or press
      # `ga` to switch provider. `?` in the chat buffer lists all keymaps.
      assistant.codecompanion-nvim = {
        enable = true;
        setupOpts = {
          display.chat.show_settings = true; # editable model/params atop the chat
          interactions.chat.adapter = "openai"; # starting provider; swap live with `ga`
          interactions.inline.adapter = "openai";
        };
      };
    };
  };
}
