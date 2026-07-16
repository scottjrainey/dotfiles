{ config, pkgs, lib, user, ... }:

let
  dotfiles = "${config.home.homeDirectory}/.dotfiles";
  # NOT config.home.homeDirectory here: imports is resolved before config is
  # available, so referencing config while computing imports is an infinite
  # recursion. user (a plain function argument) is safe.
  privateModule = "/Users/${user}/.dotfiles-private/home-module.nix";
in

{
  # Optional private companion module (see dotfiles-private/home-module.nix).
  # Guarded so this flake still evaluates/builds on a machine where the
  # private repo isn't checked out. Reading a path outside this flake's own
  # source tree is impure: darwin-rebuild/nix must be invoked with --impure,
  # or pathExists silently returns false and this import is always skipped.
  imports = lib.optional (builtins.pathExists privateModule) privateModule;

  home.username = user;
  home.homeDirectory = "/Users/${user}";
  home.stateVersion = "24.11";

  home.packages = with pkgs; [
    zsh
    nushell
    eza
    yazi
    bat
    btop
    tmux
    neovim
    luarocks
    ripgrep
    fd
    jq
    yq-go
    git
    gh
    delta
    git-filter-repo
    lazygit
    xh
    nmap
    uv
    nodejs_22 # Includes corepack.
    shellcheck
    just
    tectonic
    ghostscript
    pandoc
    poppler
  ];
  # starship, fzf, and mise packages come from their programs.* modules below.

  fonts.fontconfig.enable = true;

  home.sessionVariables = {
    EDITOR = "nvim";
    VISUAL = "nvim";
    XDG_CONFIG_HOME = "${config.home.homeDirectory}/.config";
    XDG_CACHE_HOME = "${config.home.homeDirectory}/.cache";
    XDG_DATA_HOME = "${config.home.homeDirectory}/.local/share";
    RIPGREP_CONFIG_PATH = "${config.home.homeDirectory}/.config/ripgrep/config";
  };

  home.sessionPath = [
    "/usr/local/bin"
    "/usr/local/sbin"
    "${config.home.homeDirectory}/.local/bin"
    "${config.home.homeDirectory}/.lmstudio/bin"
  ];

  programs.starship.enable = true;
  programs.fzf.enable = true;
  programs.mise.enable = true;

  programs.zsh = {
    enable = true;
    autosuggestion.enable = true;
    oh-my-zsh = {
      enable = true;
      plugins = [ "git" "sudo" "vi-mode" ];
      # Real writable path (not the read-only Nix store) so external
      # installers - e.g. openspec's completion script - have somewhere to land.
      custom = "${config.home.homeDirectory}/.oh-my-zsh/custom";
    };
    shellAliases = {
      ls = "eza -lh --group-directories-first --icons --hyperlink";
      lsa = "ls -a";
      lt = "eza --tree --level=2 --long --icons --git";
      lta = "lt -a";
      cld = "claude";
      cldp = "claude -p";
      cldo = "claude --model opus";
      clds = "claude --model sonnet";
      cldy = "claude --dangerously-skip-permissions --model sonnet";
      cldys = "claude --dangerously-skip-permissions --model sonnet";
      cldyo = "claude --dangerously-skip-permissions --model opus";
      cldpy = "claude -p --dangerously-skip-permissions";
      cldpyo = "claude -p --dangerously-skip-permissions --model opus";
      cldr = "claude --resume";
    };
    initContent = lib.mkMerge [
      # Must load before oh-my-zsh's compinit call (order 800), or the
      # completion script won't be picked up.
      (lib.mkOrder 750 ''
        fpath=("${config.home.homeDirectory}/.oh-my-zsh/custom/completions" $fpath)
      '')
      ''
        # Default to xterm-256color when terminfo is unknown
        if ! infocmp >/dev/null 2>&1; then
          export TERM=xterm-256color
        fi
      ''
    ];
  };

  # Edit-in-place: the real files stay in this repo, and $HOME points at them.
  home.file.".config/btop/btop.conf".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/.config/btop/btop.conf";
  home.file.".config/ccstatusline".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/.config/ccstatusline";
  # cmux embeds Ghostty, so terminal appearance (font, theme, transparency,
  # blur, padding, keybinds) is inherited from ~/.config/ghostty/config below.
  # This file only manages cmux-specific behavior. `cmux reload-config` reloads
  # both this and the Ghostty config in place.
  home.file.".config/cmux/cmux.json".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/.config/cmux/cmux.json";
  # Legacy source name: ghostty.config.
  home.file.".config/ghostty/config".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/.config/ghostty/config";
  home.file.".config/nvim".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/.config/nvim";
  # Legacy source name: ripgreprc.
  home.file.".config/ripgrep/config".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/.config/ripgrep/config";
  home.file.".config/starship.toml".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/.config/starship.toml";
  home.file.".config/tmux/tmux.conf".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/.config/tmux/tmux.conf";
  home.file.".skhdrc".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/.skhdrc";
  home.file.".yabairc".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/.yabairc";
  home.file.".zprofile".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/.zprofile";
  # .zshrc itself is generated by programs.zsh above, not symlinked.

  home.file."Library/LaunchAgents/io.gechr.WhichSpace.plist".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/Library/LaunchAgents/io.gechr.WhichSpace.plist";

  # Aerospace was present but commented out in scripts/install.sh, so preserve
  # the file under home/ without managing the live config yet.
  # home.file.".config/aerospace/aerospace.toml".source =
  #   config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/.config/aerospace/aerospace.toml";

  home.file.".claude/CLAUDE.md".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/AGENTS.md";
  home.file.".codex/AGENTS.md".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/AGENTS.md";
  home.file.".config/opencode/AGENTS.md".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/AGENTS.md";
}
