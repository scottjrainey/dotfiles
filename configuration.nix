{ lib, user, ... }:

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
      AppleShowAllExtensions = false; # Hide filename extensions in Finder and Spotlight.
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
      StandardHideWidgets = true; # Hide desktop widgets (Calendar, Photos, etc.).
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
      "tuicr"
      "jqp"
      "mise"
      "withgraphite/tap/graphite"
      "beads"
      "supabase/tap/supabase"
      "anomalyco/tap/opencode"
      "herdr"
      "codecrafters-io/tap/codecrafters"
    ];

    casks = [
      "ghostty"
      "nikitabobko/tap/aerospace"
      "whichspace"
      "font-fira-code-nerd-font"
      "font-iosevka-term-nerd-font"
      "font-symbols-only-nerd-font"
      "docker-desktop"
      "gcloud-cli"
      "tailscale-app"
      "claude"
      "chatgpt"
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

  # nix-homebrew rebuilds HOMEBREW_REPOSITORY as a fake repo on every activation:
  # `rm -rf` the directory, then `mkdir .git` and `touch .git/HEAD`. That stub has
  # an empty HEAD and no objects/ or refs/, so git does not see it as a repository.
  # Homebrew's Settings.write only checks that `.git/config` exists before shelling
  # out to `git -C <repo> config --replace-all`, and `.git/config` appears on its
  # own as soon as brew.sh records homebrew.devcmdrun (that write uses
  # `git config --file=`, which needs no repository). From then on every setting
  # write dies with "fatal: not in a git directory" / "Command failed with exit
  # 128: git". It breaks `brew update` in a terminal, which records
  # analyticsmessage and donationmessage when stdout is a TTY, and it can abort
  # activation itself, because Tap#untapped writes the same way under
  # `brew bundle --zap`. Finishing the stub into a valid empty repository is
  # enough. No `origin` remote is added, so `brew update` still never fetches
  # into it and Homebrew stays Nix-managed.
  system.activationScripts.homebrew.text = lib.mkAfter ''
    brewRepo=/opt/homebrew/Library/.homebrew-is-managed-by-nix
    if [ -d "$brewRepo/.git" ]; then
      /bin/mkdir -p "$brewRepo/.git/objects/info" "$brewRepo/.git/objects/pack" \
        "$brewRepo/.git/refs/heads" "$brewRepo/.git/refs/tags"
      if [ ! -s "$brewRepo/.git/HEAD" ]; then
        printf 'ref: refs/heads/master\n' > "$brewRepo/.git/HEAD"
      fi
      # Settings.read/write both bail out early unless .git/config exists, so
      # without this brew silently fails to remember anything and reprints its
      # analytics and donation notices on every single `brew update`.
      if [ ! -e "$brewRepo/.git/config" ]; then
        printf '[core]\n\trepositoryformatversion = 0\n\tbare = false\n' > "$brewRepo/.git/config"
      fi
      /usr/sbin/chown -R ${user} "$brewRepo/.git"
    fi
  '';
}
