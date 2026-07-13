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
    starship
    fzf
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
    mise
    uv
    nodejs_22 # Includes corepack.
    shellcheck
    just
    tectonic
    ghostscript
    pandoc
    poppler
  ];

  fonts.fontconfig.enable = true;
  home.sessionVariables.EDITOR = "nvim";

  # Edit-in-place: the real files stay in this repo, and $HOME points at them.
  home.file.".config/btop/btop.conf".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/.config/btop/btop.conf";
  home.file.".config/ccstatusline".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/.config/ccstatusline";
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
  home.file.".zshrc".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/.zshrc";
  # Legacy source directory: oh-my-zsh-plugins.
  home.file.".oh-my-zsh/custom/plugins/cli-agents".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/.oh-my-zsh/custom/plugins/cli-agents";

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
