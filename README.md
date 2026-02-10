# Dotfiles

A collection of configuration files for a cross-platform development environment, managed with mise and Homebrew.

Supports both **macOS** and **Linux** (including devcontainers and VMs for isolated agentic work).

## What's Included

### Shell Environment
- **zsh**: Shell configuration with Oh My Zsh
- **starship**: Cross-shell prompt (managed by mise)
- **fzf**: Fuzzy finder integration (managed by mise)

### Terminal & Editor
- **ghostty**: Terminal emulator (macOS only)
- **neovim**: Neovim with LazyVim configuration (managed by mise)
- **tmux**: Terminal multiplexer

### Window Management (macOS only)
- **aerospace**: Tiling window manager for macOS
- **karabiner-elements**: Keyboard customization

### Development Tools (managed by mise)
- **Languages**: node (22), python (3.14), bun
- **CLI Tools**: bat, bat-extras, delta, eza, fd, fzf, gh, jj, jqp, lazygit, neovim, ripgrep, starship, xh, yq, uv
- **Other**: claude, codex

### Additional Tools (via Homebrew)
- **Utilities**: git-filter-repo, mprocs, nmap, nushell, pipx, tectonic, codecrafters
- **Fonts**: Fira Code Nerd Font, Iosevka Term Nerd Font, Symbols Only Nerd Font
- **Dependencies**: ghostscript, luarocks
- **Cloud**: Google Cloud CLI

## Installation

### Prerequisites

**macOS:**
Install Homebrew if you haven't already:

```sh
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

**Linux:**
Homebrew is optional on Linux. You can install mise and other tools using your system's package manager, or install [Homebrew on Linux](https://docs.brew.sh/Homebrew-on-Linux).

### Installation Steps

1. Clone this repository to `~/repos/dotfiles`:

```sh
mkdir -p ~/repos
git clone <your-repo-url> ~/repos/dotfiles
cd ~/repos/dotfiles
```

2. Install dependencies:

**macOS with Homebrew:**
```sh
brew bundle --file=Brewfile
```

**Linux:**
Install mise and other required tools using your package manager. Core requirements: mise, zsh, git.

3. Install Oh My Zsh if not already installed:

```sh
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
```

4. Install zsh-autosuggestions plugin:

```sh
git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions
```

5. Install mise-managed tools:

```sh
mise install
```

6. Symlink configuration files (automatically detects OS and links appropriate configs):

```sh
./install.sh
```

7. Restart your terminal or source the new configuration:

```sh
source ~/.zshrc
```

## Notes

### Cross-Platform Support

The dotfiles work on both macOS and Linux environments. The installation script automatically detects the operating system and only links platform-specific configurations when appropriate.

**Platform-specific tools:**
- **macOS only**: ghostty, aerospace, karabiner-elements
- **All platforms**: zsh, starship, fzf, neovim, tmux, mise-managed tools

On Linux systems (including devcontainers and VMs), the macOS-specific configurations are skipped entirely, allowing you to use the same dotfiles repository across different environments.

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

The `install.sh` script creates symlinks for:
- `~/.config/mise/config.toml` → `_mise.toml`
- `~/.config/mise/mise.lock` → `_mise.lock`
- `~/.config/aerospace/aerospace.toml` → `aerospace.toml`
- `~/.config/ghostty/config` → `ghostty.config`
- `~/.config/nvim` → `nvim/`
- `~/.config/ripgrep/config` → `ripgreprc`
- `~/.config/starship.toml` → `starship.toml`
- `~/.config/tmux/tmux.conf` → `tmux.conf`
- `~/.zshrc` → `zshrc`
- `~/.claude/settings.json` → `claude/settings.json`
- `~/.claude/commands` → `claude/commands/`
- `~/.claude/plugins/installed_plugins.json` → `claude/plugins/installed_plugins.json`
- `~/.claude/plugins/known_marketplaces.json` → `claude/plugins/known_marketplaces.json`
- `~/.oh-my-zsh/custom/plugins/*` → `oh-my-zsh-plugins/*`
- `~/.local/bin` → `bin/`
