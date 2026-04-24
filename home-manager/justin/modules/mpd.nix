{ config, pkgs, lib, ... }:
let
  # Read base16 colours from Stylix for rmpc theming
  scheme = config.lib.stylix.colors.withHashtag;
in
{
  services.mpd = {
    enable = true;
    musicDirectory = "${config.home.homeDirectory}/Music";
    extraConfig = ''
      audio_output {
        type "pipewire"
        name "PipeWire Output"
      }

      # FIFO output for cava visualizer
      audio_output {
        type   "fifo"
        name   "cava_fifo"
        path   "/tmp/mpd.fifo"
        format "44100:16:2"
      }

      auto_update "yes"
    '';
  };

  programs.ncmpcpp = {
    enable = true;
    settings = {
      # Connection
      mpd_host = "127.0.0.1";
      mpd_port = 6600;
      mpd_crossfade_time = 3;

      # UI
      user_interface = "alternative";
      header_visibility = "yes";
      statusbar_visibility = "yes";
      titles_visibility = "yes";
      enable_window_title = "yes";
      cyclic_scrolling = "yes";
      mouse_support = "yes";

      # Progress bar
      progressbar_look = "━━╸";

      # Song format
      song_list_format = "{$5%a$9 - }{$2%t$9}|{$2%f$9}$R{$7%l$9}";
      song_status_format = "{%a - }{%t}|{%f} - {%b}";
      song_columns_list_format = "(25)[cyan]{a} (40)[white]{t|f:Title} (25)[magenta]{b} (7f)[yellow]{l}";

      # Browser
      browser_display_mode = "columns";
      search_engine_display_mode = "columns";
      playlist_editor_display_mode = "columns";

      # Misc
      display_bitrate = "yes";
      autocenter_mode = "yes";
      centered_cursor = "yes";
      ignore_leading_the = "yes";
      empty_tag_marker = "";
      external_editor = "nvim";

      # Visualizer (built-in)
      visualizer_data_source = "/tmp/mpd.fifo";
      visualizer_output_name = "cava_fifo";
      visualizer_in_stereo = "yes";
      visualizer_type = "ellipse";
      visualizer_fps = 30;
      visualizer_look = "●▮";
    };

    bindings = [
      { key = "j"; command = "scroll_down"; }
      { key = "k"; command = "scroll_up"; }
      { key = "h"; command = "previous_column"; }
      { key = "l"; command = "next_column"; }
      { key = "J"; command = [ "select_item" "scroll_down" ]; }
      { key = "K"; command = [ "select_item" "scroll_up" ]; }
      { key = "d"; command = "delete_playlist_items"; }
      { key = "v"; command = "show_visualizer"; }
    ];
  };

  # MPRIS bridge — exposes mpd to QuickShell media controls
  services.mpdris2 = {
    enable = true;
    notifications = false;
  };

  # rmpc — TUI mpd client with album art
  home.packages = [ pkgs.mpc pkgs.rmpc ];

  xdg.configFile."rmpc/config.ron".text = ''
    #![enable(implicit_some)]
    #![enable(unwrap_newtypes)]
    #![enable(unwrap_variant_newtypes)]
    (
        address: "127.0.0.1:6600",
        theme: None,
        cache_dir: None,
        volume_step: 5,
        max_fps: 30,
        scrolloff: 2,
        wrap_navigation: true,
        enable_mouse: true,
        status_update_interval_ms: 500,
        select_current_song_on_change: true,
        album_art: (
            method: Auto,
            max_size_px: (width: 800, height: 800),
            disabled_protocols: ["http://", "https://"],
            vertical_align: Center,
            horizontal_align: Center,
        ),
    )
  '';

  xdg.configFile."rmpc/theme.ron".text = ''
    #![enable(implicit_some)]
    #![enable(unwrap_newtypes)]
    #![enable(unwrap_variant_newtypes)]
    (
        background_color: "${scheme.base00}",
        text_color: "${scheme.base05}",
        header_background_color: "${scheme.base01}",
        modal_background_color: "${scheme.base01}",
        modal_backdrop: true,
        highlighted_item_style: (fg: "${scheme.base0D}", modifiers: "Bold"),
        current_item_style: (fg: "${scheme.base00}", bg: "${scheme.base0D}", modifiers: "Bold"),
        borders_style: (fg: "${scheme.base03}"),
        highlight_border_style: (fg: "${scheme.base0D}"),
        preview_label_style: (fg: "${scheme.base0A}"),
        preview_metadata_group_style: (fg: "${scheme.base0A}", modifiers: "Bold"),
        symbols: (
            song: "♪",
            dir: "",
            playlist: "",
            marker: "▸",
            ellipsis: "…",
        ),
        level_styles: (
            info: (fg: "${scheme.base0D}", bg: "${scheme.base00}"),
            warn: (fg: "${scheme.base0A}", bg: "${scheme.base00}"),
            error: (fg: "${scheme.base08}", bg: "${scheme.base00}"),
            debug: (fg: "${scheme.base0B}", bg: "${scheme.base00}"),
            trace: (fg: "${scheme.base0E}", bg: "${scheme.base00}"),
        ),
        progress_bar: (
            symbols: ["━", "━", "╸", " ", "━"],
            track_style: (fg: "${scheme.base02}"),
            elapsed_style: (fg: "${scheme.base0D}"),
            thumb_style: (fg: "${scheme.base0D}"),
        ),
        scrollbar: (
            symbols: ["│", "█", "▲", "▼"],
            track_style: (fg: "${scheme.base02}"),
            ends_style: (fg: "${scheme.base03}"),
            thumb_style: (fg: "${scheme.base0D}"),
        ),
        tab_bar: (
            active_style: (fg: "${scheme.base00}", bg: "${scheme.base0D}", modifiers: "Bold"),
            inactive_style: (fg: "${scheme.base04}"),
        ),
        lyrics: (
            timestamp: false
        ),
    )
  '';
}
