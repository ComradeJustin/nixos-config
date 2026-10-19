# nvf editor configuration.
#
# This is the hand-edited "what goes in the editor" file. It is imported by
# modules/core/nvf.nix into `nvf.lib.neovimConfiguration`, which builds a
# self-contained Neovim exposed as the `nvf` command (stock `neovim`/`nvim`
# stays untouched — see modules/core/nvf.nix).
#
# Theming note: the base16 palette is injected separately by nvf.nix from the
# system Stylix colors when `modules.theming.enable` is on. The name and style
# set here are the fallback for hosts without Stylix.
{ lib, ... }:
{
  vim = {
    # Do NOT claim the vi/vim/nvim aliases — those belong to the stock neovim
    # package. This build is only ever invoked as `nvf`.
    viAlias = false;
    vimAlias = false;

    theme = {
      enable = true;
      # nvf's own defaults are also mkDefault (name "onedark", style "darker").
      # A plain mkDefault ties and the build fails on hosts without Stylix.
      # 999 beats that default (1000) and still loses to the normal-priority
      # base16 theme. "darker" is not a gruvbox style.
      name = lib.mkOverride 999 "gruvbox";
      style = lib.mkOverride 999 "dark";
      transparent = false;
    };

    # Core UI / editing
    statusline.lualine.enable = true;
    telescope.enable = true;
    autocomplete.nvim-cmp.enable = true;
    treesitter.enable = true;

    # Navigation / buffers
    filetree.neo-tree.enable = true;      # <leader> file explorer
    tabline.nvimBufferline.enable = true; # buffer bar
    binds.whichKey.enable = true;         # keybind popup helper
    utility.motion.flash-nvim.enable = true;

    # Git suite: gitsigns + fugitive + git-conflict + gitlinker + hunk
    git.enable = true;

    # Visual niceties
    visuals = {
      indent-blankline.enable = true;
      fidget-nvim.enable = true;          # LSP progress spinner
      highlight-undo.enable = true;
    };
    ui = {
      borders.enable = true;
      colorizer.enable = true;            # inline #rrggbb / color previews
    };

    # LSP + language tooling
    lsp.enable = true;
    languages = {
      enableFormat = true;
      enableTreesitter = true;

      nix.enable = true;
      bash.enable = true;
      markdown.enable = true;
      # Add more as needed, e.g.:
      # rust.enable = true;
      python.enable = true;
      # ts.enable = true;
      # clang.enable = true;
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
        display.chat.show_settings = true;      # editable model/params atop the chat
        interactions.chat.adapter = "openai";   # starting provider; swap live with `ga`
        interactions.inline.adapter = "openai";
      };
    };
  };
}
