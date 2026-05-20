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
- **karabiner-elements**: Keyboard customization

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

4. Install zsh-autosuggestions plugin:

```sh
git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions
```

5. Symlink configuration files (symlinks configuration files into ~/.config and ~):

```sh
./scripts/install.sh
```

If a sibling `~/repos/dotfiles-private` repo is present, the installer dispatches into it automatically to layer on personal/private symlinks (e.g. `~/.gitconfig`, `~/.claude/`).

6. Restart your terminal or source the new configuration:

```sh
source ~/.zshrc
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

If a sibling `~/repos/dotfiles-private` is present, `scripts/install.sh` then runs `dotfiles-private/scripts/install.sh`, which layers on private symlinks (`~/.gitconfig`, curated entries under `~/.claude/`, etc.).
