# Dotfiles

A collection of configuration files for a macOS development environment, managed with Homebrew.

## What's Included

### Shell Environment
- **zsh**: Shell configuration with Oh My Zsh
- **starship**: Cross-shell prompt
- **fzf**: Fuzzy finder integration

### Terminal & Editor
- **ghostty**: Terminal emulator
- **neovim**: Neovim with LazyVim configuration
- **tmux**: Terminal multiplexer

### Window Management
- **yabai**: Tiling window manager for macOS (replaces aerospace)
- **skhd**: Hotkey daemon paired with yabai (yabai has no built-in hotkey support)
- **WhichSpace**: Menu bar Space indicator settings export
- **karabiner-elements**: Keyboard customization

Window management assumes **6 macOS Spaces created in a specific order** — yabai labels them by index, WhichSpace badges them by index, and several `yabai -m rule` lines pin apps to those labels. See [First-time Spaces setup](#first-time-spaces-setup) below.

### Development Tools (via Homebrew)
- **CLI Tools**: bat, bat-extras, delta, eza, fd, fzf, jq, jqp, lazygit, neovim, node, ripgrep, starship, uv, xh, yq

### Additional Tools (via Homebrew)
- **Utilities**: git-filter-repo, just, mprocs, nmap, nushell, shellcheck, tectonic, codecrafters
- **Apps**: Claude Code
- **Fonts**: Fira Code Nerd Font, Iosevka Term Nerd Font, Symbols Only Nerd Font
- **Dependencies**: ghostscript, luarocks
- **Cloud**: Google Cloud CLI

## Installation

### Prerequisites

Install Homebrew if you haven't already:

```sh
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

### Installation Steps

1. Clone this repository to `~/repos/dotfiles`:

```sh
mkdir -p ~/repos
git clone <your-repo-url> ~/repos/dotfiles
cd ~/repos/dotfiles
```

2. Install dependencies:

```sh
brew bundle --file=Brewfile
```

3. Install Oh My Zsh if not already installed:

```sh
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
```

4. Create the 6 macOS Spaces (Mission Control). The default install has 1 Space — yabai and WhichSpace both need 6, in this order:

   | Index | Label | WhichSpace badge |
   |-------|-----------|---|
   | 1     | browser   | B |
   | 2     | calendar  | C |
   | 3     | editor    | E |
   | 4     | mail      | M |
   | 5     | notes     | N |
   | 6     | terminal  | T |

   Open Mission Control (Ctrl+↑ or three-finger swipe up), hover the Spaces bar at the top, and click the **+** five times. macOS exposes no CLI for this — see [First-time Spaces setup](#first-time-spaces-setup) for details and how to recover if the order gets out of sync.

5. Symlink configuration files (symlinks configuration files into ~/.config and ~):

```sh
./scripts/install.sh
```

The installer also clones third-party oh-my-zsh plugins listed in `ZSH_PLUGINS_THIRD_PARTY` (currently `zsh-autosuggestions`) into `~/.oh-my-zsh/custom/plugins/`. If a sibling `~/repos/dotfiles-private` repo is present, it dispatches into that to layer on personal/private symlinks (e.g. `~/.gitconfig`, `~/.claude/`).

6. Restart your terminal or source the new configuration:

```sh
source ~/.zshrc
```

7. Import WhichSpace settings (badges only align if step 4 was completed first):

Open the WhichSpace menu bar menu, choose **Import Settings…**, and select:

```text
~/repos/dotfiles/whichspace/WhichSpaceSettings.json
```

## Notes

### Repository Location

This dotfiles repository should be placed in `~/repos/dotfiles` rather than `~/dotfiles` or `~/Documents`. macOS applies stricter privacy controls (TCC) to directories like `~/Documents`, `~/Desktop`, and `~/Downloads`.

Apps—especially sandboxed ones, like Aerospace—must request explicit user permission to access these locations, even if the file path is valid and the file exists. When a config file is symlinked to somewhere inside `~/Documents`, macOS sees it as an access to a protected location and may deny access silently or log it.

Placing `dotfiles` in a less restricted path like `~/repos/dotfiles` avoids these privacy controls, and apps can freely follow symlinks without triggering System Policy denials.

### Custom Location

The `install.sh` script defaults to `DOTFILES_TARGET="$HOME/.dotfiles"`. If your dotfiles are at `~/repos/dotfiles` (recommended), set the variable before running:

```sh
export DOTFILES_TARGET="$HOME/repos/dotfiles"
./install.sh
```

### What Gets Symlinked

The `scripts/install.sh` script creates symlinks for:
- `~/.skhdrc` → `skhdrc`
- `~/.yabairc` → `yabairc`
- `~/.zprofile` → `zprofile`
- `~/.zshrc` → `zshrc`
- `~/.config/btop/btop.conf` → `btop.conf`
- `~/.config/ccstatusline` → `ccstatusline/`
- `~/.config/ghostty/config` → `ghostty.config`
- `~/.config/nvim` → `nvim/`
- `~/.config/ripgrep/config` → `ripgreprc`
- `~/.config/starship.toml` → `starship.toml`
- `~/.config/tmux/tmux.conf` → `tmux.conf`
- `~/.oh-my-zsh/custom/plugins/*` → `oh-my-zsh-plugins/*`
- `~/Library/LaunchAgents/io.gechr.WhichSpace.plist` → `whichspace/io.gechr.WhichSpace.plist`

If a sibling `~/repos/dotfiles-private` is present, `scripts/install.sh` then runs `dotfiles-private/scripts/install.sh`, which layers on private symlinks (`~/.gitconfig`, curated entries under `~/.claude/`, etc.).

### First-time Spaces setup

macOS ships with one Space by default. This setup needs six, in a specific order, because:

- `yabairc` labels Spaces **by index** on first run (`browser` → 1, `calendar` → 2, …, `terminal` → 6). Those labels are referenced by `yabai -m rule --add app=... space=editor` and similar lines, so wrong order means apps land on the wrong Space.
- `whichspace/WhichSpaceSettings.json` hardcodes badges (B, C, E, M, N, T) against indexes 1–6.

**Create them via Mission Control**: there is no public macOS API to add Spaces — yabai can't create them under SIP on Apple Silicon either. Open Mission Control (Ctrl+↑ or three-finger swipe up), hover the Spaces bar, and click **+** until you have six. Drag them into `browser, calendar, editor, mail, notes, terminal` order.

**Once yabai applies labels, it won't re-label**: `init_space_labels_if_needed` in `yabairc` is intentionally one-shot — if all six labels are already present, it leaves Space identity alone so you can rearrange Spaces in Mission Control without losing them. If you ever need to reset (e.g. after recreating Spaces), unlabel them and let yabai relabel on its next start:

```sh
for i in 1 2 3 4 5 6; do yabai -m space "$i" --label "" 2>/dev/null; done
yabai --restart-service   # or: brew services restart yabai
```

If yabai logs `skipped space relabeling: ...` and emits a notification on startup, that means it found a partial/mismatched label state and refused to overwrite — usually because the Spaces order in Mission Control no longer matches `browser, calendar, editor, mail, notes, terminal`. Fix the order (or clear labels as above) and restart yabai.

### WhichSpace

The app is installed via `brew bundle` (cask `gechr/tap/whichspace`) and `scripts/install.sh` symlinks a per-user LaunchAgent at `~/Library/LaunchAgents/io.gechr.WhichSpace.plist` so WhichSpace starts at login. The installer also `launchctl bootstrap`s it immediately, so you don't need to log out to pick it up.

Settings are tracked as an app-supported JSON export at `whichspace/WhichSpaceSettings.json`. Re-import them manually through the WhichSpace menu bar app after the installer runs (the app has no CLI for this).

To disable auto-launch:

```sh
launchctl bootout "gui/$(id -u)/io.gechr.WhichSpace"
rm ~/Library/LaunchAgents/io.gechr.WhichSpace.plist
```
