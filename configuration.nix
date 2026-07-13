{ user, ... }:

{
  # Determinate Nix manages the daemon, so nix-darwin should not.
  nix.enable = false;

  nixpkgs.config.allowUnfree = true;
  nixpkgs.hostPlatform = "aarch64-darwin"; # Use x86_64-darwin on Intel Macs.

  system.primaryUser = user;
  users.users.${user} = {
    home = "/Users/${user}";
  };
  system.stateVersion = 6;

  system.defaults = {
    NSGlobalDomain = {
      AppleInterfaceStyle = "Dark"; # Use dark mode.
      KeyRepeat = 2; # Use fast key repeat.
      InitialKeyRepeat = 15; # Shorten the delay before key repeat starts.
      AppleShowAllExtensions = true; # Show filename extensions in Finder.
    };
    dock = {
      autohide = true; # Hide the Dock until the pointer reaches it.
    };
    finder = {
      FXPreferredViewStyle = "Nlsv"; # Use list view by default.
      CreateDesktop = false; # Keep desktop icons hidden.
    };
    trackpad = {
      Clicking = true; # Enable tap to click.
    };
  };

  nix-homebrew = {
    enable = true;
    inherit user;
    # This Mac has a pre-existing standalone Homebrew install. Without this,
    # nix-homebrew halts activation and asks whether to uninstall it (data
    # loss) or migrate it. autoMigrate only removes files tracked in
    # Homebrew's own core git repo (the brew program itself) and replaces
    # them with a Nix-store symlink; taps/Cellar/Caskroom/installed binaries
    # are untouched. Safe to leave set - the migration is one-time and this
    # is a no-op on every switch after the first.
    autoMigrate = true;
  };

  homebrew = {
    enable = true;
    onActivation.cleanup = "zap"; # Remove Homebrew packages not listed here.
    onActivation.autoUpdate = true; # Update Homebrew metadata during activation.
    onActivation.extraFlags = [ "--force" ]; # Allow cleanup to remove casks.

    taps = [
      "anomalyco/tap"
      "asmvik/formulae"
      "codecrafters-io/tap"
      "gechr/tap"
      "nikitabobko/tap"
      "supabase/tap"
      "withgraphite/tap"
    ];

    brews = [
      "asmvik/formulae/yabai"
      "asmvik/formulae/skhd"
      "bat-extras"
      "mprocs"
      "jqp"
      "withgraphite/tap/graphite"
      "beads"
      "supabase/tap/supabase"
      "anomalyco/tap/opencode"
      "codecrafters-io/tap/codecrafters"
    ];

    casks = [
      "ghostty"
      "cmux"
      "nikitabobko/tap/aerospace"
      "gechr/tap/whichspace"
      "font-fira-code-nerd-font"
      "font-iosevka-term-nerd-font"
      "font-symbols-only-nerd-font"
      "docker-desktop"
      "gcloud-cli"
      "tailscale-app"
      "claude"
      "codex-app"
      "cursor"
      "lm-studio"
      "codex"
      "google-chrome"
      "obsidian"
      "discord"
      "slack"
      "zoom"
    ];
  };
}
