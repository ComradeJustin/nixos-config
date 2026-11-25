# Note taking in Neovim (modules/editor.nix), on desktop machines: Markdown
# files in ~/notes, shown in a terminal that draws pictures (Ghostty).
#
#   - obsidian.nvim: new notes, daily notes, [[links]], backlinks, search
#   - render-markdown.nvim: headings, tables and links drawn while editing
#   - snacks.nvim: pictures and LaTeX formulas drawn in the text
#   - img-clip.nvim: paste a screenshot from the clipboard into the note
#   - molten-nvim: run a code block; its output, a plot included, is shown
#     under it
# The assistant (CodeCompanion) is set up in modules/editor.nix.
#
# Keys, all after the leader key and n:
#   n new note    f find note    s search notes    d today's note
#   b backlinks   p paste image  r run code block  x clear output
{
  config,
  lib,
  pkgs,
  ...
}:
let
  # What a code block in a note can import, and what molten-nvim itself
  # needs (jupyter-client, ipykernel, nbformat, pillow, cairosvg).
  pythonPackages = [
    "jupyter-client"
    "ipykernel"
    "nbformat"
    "pillow"
    "cairosvg"
    "numpy"
    "matplotlib"
  ];

  # molten-nvim is a "remote plugin": Neovim only knows its commands from
  # a list that `:UpdateRemotePlugins` writes. Nothing writes that list for
  # a Neovim built by Nix, so it is made here, by the finished Neovim.
  remotePlugins = pkgs.runCommand "neovim-remote-plugins" { } ''
    export HOME=$TMPDIR
    NVIM_RPLUGIN_MANIFEST=$out ${config.programs.nvf.finalPackage}/bin/nvim --headless +UpdateRemotePlugins +qa
  '';
in
{
  systemd.tmpfiles.rules = [
    # The notes folder has to exist before obsidian.nvim is set up.
    "d /home/justin/notes 0755 justin users -"
    # molten-nvim writes here when it starts a kernel, and does not make
    # the folder itself.
    "d /home/justin/.local/share/jupyter 0755 justin users -"
    "d /home/justin/.local/share/jupyter/runtime 0700 justin users -"
  ];

  # Where Neovim finds the list of remote plugins.
  environment.variables.NVIM_RPLUGIN_MANIFEST = "${remotePlugins}";

  programs.nvf.settings.vim = {
    notes.obsidian = {
      enable = true;
      setupOpts = {
        workspaces = [
          {
            name = "notes";
            path = "~/notes";
          }
        ];
        daily_notes.folder = "daily";
        # Only the `:Obsidian <command>` form, not the older one-word commands.
        legacy_commands = false;
        # A note's file is named after its title ("Fourier series" becomes
        # fourier-series.md), not after the time it was made.
        note_id_func = lib.generators.mkLuaInline ''
          function(title)
            if title == nil or title == "" then
              return tostring(os.time())
            end
            local name = title:lower():gsub("[^%w%s%-]", ""):gsub("%s+", "-")
            return name
          end
        '';
      };
    };
    # obsidian.nvim brings vim-markdown, which folds every heading shut
    # when a note is opened.
    globals.vim_markdown_folding_disabled = 1;

    languages.markdown.extensions.render-markdown-nvim.enable = true;

    utility.snacks-nvim = {
      enable = true;
      setupOpts.image = {
        enabled = true;
        # A picture's path is read as Markdown means it: from the folder
        # the note is in. nvf would have obsidian.nvim look it up in one
        # folder for the whole vault, which misses "assets/name.png".
        resolve = lib.mkForce null;
      };
    };
    # snacks.nvim finds the formulas in a note with the LaTeX grammar.
    treesitter.grammars = [ pkgs.vimPlugins.nvim-treesitter.builtGrammars.latex ];
    # What snacks.nvim needs to turn formulas and other pictures into ones
    # the terminal can show. tectonic fetches the LaTeX packages it needs
    # the first time a formula is drawn.
    extraPackages = [
      pkgs.imagemagick
      pkgs.ghostscript
      pkgs.tectonic
      # The kernel that runs code blocks is started as plain "python": this
      # makes that the Python with the packages above.
      (pkgs.python3.withPackages (available: map (name: available.${name}) pythonPackages))
    ];

    utility.images.img-clip = {
      enable = true;
      # Pictures are kept in an assets folder beside the note they are in.
      setupOpts.default = {
        dir_path = "assets";
        relative_to_current_file = true;
      };
    };

    # molten-nvim is written in Python and talks to a Jupyter kernel.
    extraPlugins.molten-nvim.package = pkgs.vimPlugins.molten-nvim;
    withPython3 = true;
    python3Packages = pythonPackages;
    globals = {
      molten_image_provider = "snacks.nvim";
      # Output is written under the code block, not in a floating window.
      molten_virt_text_output = true;
      molten_auto_open_output = false;
    };

    keymaps = [
      {
        key = "<leader>nn";
        mode = "n";
        action = "<cmd>Obsidian new<cr>";
        desc = "New note";
      }
      {
        key = "<leader>nf";
        mode = "n";
        action = "<cmd>Obsidian quick_switch<cr>";
        desc = "Find note";
      }
      {
        key = "<leader>ns";
        mode = "n";
        action = "<cmd>Obsidian search<cr>";
        desc = "Search notes";
      }
      {
        key = "<leader>nd";
        mode = "n";
        action = "<cmd>Obsidian today<cr>";
        desc = "Today's note";
      }
      {
        key = "<leader>nb";
        mode = "n";
        action = "<cmd>Obsidian backlinks<cr>";
        desc = "Backlinks";
      }
      {
        key = "<leader>np";
        mode = "n";
        action = "<cmd>PasteImage<cr>";
        desc = "Paste image";
      }
      {
        key = "<leader>nr";
        mode = "n";
        lua = true;
        desc = "Run code block";
        action = ''
          function()
            -- The nearest fence at or above the cursor. An opening fence
            -- names a language; a closing one is bare, and means the cursor
            -- is not inside a block.
            local opening = vim.fn.search("^```", "bcnW")
            if opening == 0 or vim.fn.getline(opening):match("^```%s*$") then
              vim.notify("The cursor is not inside a code block")
              return
            end
            local closing = vim.fn.search("^```\\s*$", "nW")
            if closing == 0 then
              vim.notify("This code block is not closed")
              return
            end
            local function run()
              vim.fn.MoltenEvaluateRange(opening + 1, closing - 1)
            end
            if #vim.fn.MoltenRunningKernels(true) > 0 then
              run()
              return
            end
            -- The first run in a note starts the Python kernel. A block
            -- handed over before the kernel is ready is never run, so the
            -- block waits for molten-nvim to say that it is.
            vim.api.nvim_create_autocmd("User", {
              pattern = "MoltenKernelReady",
              once = true,
              callback = vim.schedule_wrap(run),
            })
            vim.cmd("MoltenInit python3")
          end
        '';
      }
      {
        key = "<leader>nx";
        mode = "n";
        action = "<cmd>MoltenDelete<cr>";
        desc = "Clear output";
      }
    ];
  };
}
