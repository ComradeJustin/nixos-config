# Note taking in Neovim (modules/editor.nix), on desktop machines: Markdown
# files in ~/notes, shown in a terminal that draws pictures (Ghostty).
#
#   - obsidian.nvim: new notes, daily notes, [[links]], backlinks, search
#   - render-markdown.nvim: headings, tables and links drawn while editing
#   - snacks.nvim: pictures and LaTeX formulas drawn in the text
#   - img-clip.nvim: paste a screenshot from the clipboard into the note
#   - molten-nvim: run a code block (Python, TypeScript, JavaScript); its
#     output, a plot included, is shown under it
#   - otter.nvim: completion inside code blocks and formulas, from the
#     language servers for Python, TypeScript and LaTeX
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
  # The Python that runs a note's Python code blocks. What is listed here
  # is what a block can import; ipykernel is what lets it be run at all.
  notesPython = pkgs.python3.withPackages (available: [
    available.ipykernel
    available.numpy
    available.matplotlib
  ]);

  # The kernels a code block can be run with (a kernel is the program that
  # runs the code and hands back what it printed or drew), each in a folder
  # named as molten-nvim knows it. Each is started by its full path, so it
  # does not matter which python or deno a shell would find first.
  kernelCommands = {
    python3 = [
      "${notesPython}/bin/python"
      "-m"
      "ipykernel_launcher"
      "-f"
      "{connection_file}"
    ];
    # Deno runs TypeScript and JavaScript.
    deno = [
      "${pkgs.deno}/bin/deno"
      "jupyter"
      "--kernel"
      "--conn"
      "{connection_file}"
    ];
  };
  kernels = pkgs.runCommand "notes-kernels" { } (
    lib.concatStrings (
      lib.mapAttrsToList (name: command: ''
        mkdir -p $out/share/jupyter/kernels/${name}
        cp ${
          pkgs.writeText "kernel.json" (
            builtins.toJSON {
              argv = command;
              display_name = name;
              language = name;
            }
          )
        } $out/share/jupyter/kernels/${name}/kernel.json
      '') kernelCommands
    )
  );

  # The Python language server, when it looks at a note's code blocks, is
  # told where the packages a block can import are.
  notesPyrightConfig = pkgs.writeText "pyrightconfig.json" (
    builtins.toJSON { extraPaths = [ "${notesPython}/${notesPython.sitePackages}" ]; }
  );

  # What molten-nvim, which is written in Python, needs for itself.
  moltenPythonPackages = [
    "jupyter-client"
    "nbformat"
    "pillow"
    "cairosvg"
  ];

  # molten-nvim is a "remote plugin": Neovim only knows its commands from
  # a list that `:UpdateRemotePlugins` writes. Nothing writes that list for
  # a Neovim built by Nix, so it is made here, by a bare Neovim that has
  # only molten-nvim and the Python to load it with.
  remotePlugins = pkgs.runCommand "neovim-remote-plugins" { } ''
    export HOME=$TMPDIR
    NVIM_RPLUGIN_MANIFEST=$out ${config.programs.nvf.settings.vim.package}/bin/nvim -u NORC --headless \
      --cmd "set runtimepath+=${pkgs.vimPlugins.molten-nvim}" \
      --cmd "let g:python3_host_prog = '${
        pkgs.python3.withPackages (
          available: [ available.pynvim ] ++ map (name: available.${name}) moltenPythonPackages
        )
      }/bin/python'" \
      +UpdateRemotePlugins +qa
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
    # Two files the language servers look for in the notes folder: where
    # Python's packages are, and (empty) the mark without which Deno's
    # language server does not answer for a folder at all.
    "L+ /home/justin/notes/pyrightconfig.json - - - - ${notesPyrightConfig}"
    "L+ /home/justin/notes/deno.json - - - - ${pkgs.writeText "deno.json" "{}"}"
  ];

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

    languages.markdown.extensions.render-markdown-nvim = {
      enable = true;
      # The note stays drawn while typing too; only the line the cursor is
      # on shows its source. Otherwise every formula's source appears
      # beside its picture each time insert mode is entered.
      setupOpts.render_modes = true;
    };

    utility.snacks-nvim = {
      enable = true;
      setupOpts.image = {
        enabled = true;
        # A picture's path is read as Markdown means it: from the folder
        # the note is in. nvf would have obsidian.nvim look it up in one
        # folder for the whole vault, which misses "assets/name.png".
        resolve = lib.mkForce null;

        # How a formula is turned into a picture. This is snacks.nvim's own
        # LaTeX document with two changes, so that formulas come out at the
        # size of the text around them:
        #   - the size (snacks.nvim's own is nearly twice the text's)
        #   - snacks.nvim writes every formula between \[ and \]. Here
        #     those set it as one line that is at least a full line high
        #     (\strut), whatever is in it. snacks.nvim fits a short formula
        #     to the line of text it is in, so without this a lone x was
        #     drawn as tall as a whole line and other formulas smaller.
        # The picture is also no longer cut down to its ink (below), which
        # would cut that height off again.
        # The ''${...} parts are filled in by snacks.nvim.
        math.latex = {
          font_size = "footnotesize";
          tpl = ''
            \documentclass[preview,border=0pt,varwidth,12pt]{standalone}
            \usepackage{''${packages}}
            \begin{document}
            ''${header}
            { \''${font_size} \selectfont
              \def\[{$\displaystyle\strut}\def\]{$}
              \color[HTML]{''${color}}
            ''${content}}
            \end{document}'';
        };
        convert.magick.math = [
          "-density"
          192
          "{src}[{page}]"
        ];
      };
    };
    # What snacks.nvim needs to turn formulas and other pictures into ones
    # the terminal can show. tectonic fetches the LaTeX packages it needs
    # the first time a formula is drawn.
    extraPackages = [
      pkgs.imagemagick
      pkgs.ghostscript
      pkgs.tectonic
    ];

    utility.images.img-clip = {
      enable = true;
      # Pictures are kept in an assets folder beside the note they are in.
      setupOpts.default = {
        dir_path = "assets";
        relative_to_current_file = true;
      };
    };

    # A note is Markdown to Neovim, code blocks and formulas included.
    # otter.nvim hands each of those to the language server of its own
    # language, which is where completion comes from. It is switched on
    # whenever a Markdown file is opened.
    lsp.otter-nvim.enable = true;
    # This also brings the LaTeX grammar, which snacks.nvim needs to find
    # the formulas in a note.
    languages.tex.enable = true;
    # otter.nvim gives a formula the file type "latex", which is added here
    # to the ones the LaTeX language server already answers for.
    lsp.servers.texlab.filetypes = [ "latex" ];
    # Deno's own language server, to match the Deno that runs the blocks.
    languages.typescript = {
      enable = true;
      lsp.servers = [ "deno" ];
    };
    autocmds = [
      {
        event = [ "FileType" ];
        pattern = [ "markdown" ];
        command = "OtterActivate";
        desc = "Completion inside a note's code blocks and formulas";
      }
      # snacks.nvim draws a formula again after every change to the text,
      # so while one is being typed its picture keeps changing. These two
      # make it wait: nothing is redrawn in insert mode, and everything is
      # brought up to date on leaving it.
      {
        event = [ "FileType" ];
        pattern = [ "markdown" ];
        once = true;
        desc = "Formulas are not redrawn while typing";
        callback = lib.generators.mkLuaInline ''
          function()
            local pictures = require("snacks.image.doc")
            local find_pictures = pictures.find_visible
            pictures.find_visible = function(buffer, on_found)
              if vim.fn.mode():sub(1, 1) == "i" then
                return
              end
              find_pictures(buffer, on_found)
            end
          end
        '';
      }
      {
        event = [ "InsertLeave" ];
        pattern = [ "*.md" ];
        desc = "Formulas are redrawn after typing";
        callback = lib.generators.mkLuaInline ''
          function(event)
            -- snacks.nvim redraws a buffer's pictures on this event of its own.
            local group = "snacks.image.inline." .. event.buf
            if vim.fn.exists("#" .. group) == 1 then
              vim.api.nvim_exec_autocmds("BufWinEnter", { group = group, buffer = event.buf })
            end
          end
        '';
      }
    ];

    # molten-nvim runs code blocks in the kernels above.
    extraPlugins.molten-nvim.package = pkgs.vimPlugins.molten-nvim;
    withPython3 = true;
    python3Packages = moltenPythonPackages;
    # Where Neovim finds the list of remote plugins, and molten-nvim the
    # kernels. Both are set here, as Neovim starts, so that they hold in
    # any terminal and change with the next start after a rebuild.
    luaConfigRC.notes-molten = ''
      vim.env.NVIM_RPLUGIN_MANIFEST = "${remotePlugins}"
      vim.env.JUPYTER_PATH = "${kernels}/share/jupyter"
    '';
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
            -- The kernel that runs this block's language.
            local kernel_for = {
              python = "python3",
              typescript = "deno",
              ts = "deno",
              javascript = "deno",
              js = "deno",
            }
            local language = vim.fn.getline(opening):match("^```(%w+)")
            local kernel = kernel_for[language]
            if kernel == nil then
              vim.notify("Blocks in " .. tostring(language) .. " cannot be run")
              return
            end
            -- A note's kernel is known by its name, or by its name and a
            -- number when another note started the same one first.
            local function is_this_kernel(id)
              return id == kernel or vim.startswith(id, kernel .. "_")
            end
            for _, id in ipairs(vim.fn.MoltenRunningKernels(true)) do
              if is_this_kernel(id) then
                vim.fn.MoltenEvaluateRange(id, opening + 1, closing - 1)
                return
              end
            end
            -- The first run of a language in a note starts its kernel. A
            -- block handed over before the kernel is ready is never run, so
            -- the block waits for molten-nvim to say that it is.
            vim.api.nvim_create_autocmd("User", {
              pattern = "MoltenKernelReady",
              callback = function(event)
                local id = event.data.kernel_id
                if not is_this_kernel(id) then
                  return
                end
                vim.schedule(function()
                  vim.fn.MoltenEvaluateRange(id, opening + 1, closing - 1)
                end)
                -- Returning true removes this autocommand: it is for one run.
                return true
              end,
            })
            vim.cmd("MoltenInit " .. kernel)
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
