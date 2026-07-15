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
      KeyRepeat = 2; # Use fast key repeat.
      InitialKeyRepeat = 15; # Shorten the delay before key repeat starts.
      AppleShowAllExtensions = true; # Show filename extensions in Finder.
      AppleInterfaceStyleSwitchesAutomatically = true; # Auto-switch light/dark with the time of day.
      "com.apple.springing.delay" = 0.5; # Spring-loaded folder delay (default 1.0).
    };
    dock = {
      autohide = true; # Hide the Dock until the pointer reaches it.
      tilesize = 41; # Dock icon size (default 64).
      mru-spaces = false; # Don't reorder Spaces by most recent use.
      "wvous-br-corner" = 14; # Bottom-right hot corner: Quick Note.
    };
    finder = {
      FXPreferredViewStyle = "Nlsv"; # Use list view by default.
      CreateDesktop = false; # Keep desktop icons hidden.
    };
    trackpad = {
      Clicking = true; # Enable tap to click.
      TrackpadRightClick = true; # Two-finger tap for secondary click.
      TrackpadRotate = true; # Two-finger rotate gesture.
      TrackpadPinch = true; # Two-finger pinch to zoom.
      TrackpadFourFingerHorizSwipeGesture = 2; # Swipe between full-screen apps.
      TrackpadFourFingerPinchGesture = 2; # Four-finger pinch for Desktop/Launchpad.
      TrackpadTwoFingerDoubleTapGesture = true; # Smart zoom on double-tap.
      TrackpadTwoFingerFromRightEdgeSwipeGesture = 3; # Swipe in from right edge for Notification Center.
      TrackpadThreeFingerTapGesture = 0; # Disable three-finger tap (Look Up).
    };
    menuExtraClock = {
      ShowAMPM = true; # Show the AM/PM label.
      ShowDate = 0; # Show the full date only when space allows.
      ShowDayOfWeek = true; # Show the day of week in the menu bar.
    };
    screencapture = {
      location = "~/Documents/"; # Save screenshots to Documents instead of the Desktop.
    };
    WindowManager = {
      EnableTiledWindowMargins = false; # No gaps between tiled windows.
    };
    loginwindow = {
      GuestEnabled = false; # Disable the Guest account.
    };
    SoftwareUpdate = {
      AutomaticallyInstallMacOSUpdates = true; # Auto-install macOS updates.
    };
    ActivityMonitor = {
      ShowCategory = 102; # Show "My Processes" by default.
      OpenMainWindow = false; # Don't auto-open the main window on launch.
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
      "whichspace"
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
