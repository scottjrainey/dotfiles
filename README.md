# Dotfiles

A collection of configuration files for a development environment on macOS, managed with mise and Homebrew.

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
- **aerospace**: Tiling window manager for macOS
- **karabiner-elements**: Keyboard customization

### Development Tools (managed by mise)
- **Languages**: node (22), python (3.14), bun
- **CLI Tools**: bat, bat-extras, delta, eza, fd, gh, jj, jqp, lazygit, ripgrep, xh, yq, uv
- **Infrastructure**: terraform
- **Other**: claude, nasm

### Additional Tools (via Homebrew)
- **Utilities**: git-filter-repo, mprocs, nmap, nushell, pipx, tectonic, codecrafters
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

2. Install Homebrew dependencies (includes mise):

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

5. Install mise-managed tools:

```sh
mise install
```

6. Symlink configuration files:

```sh
./install.sh
```

7. Restart your terminal or source the new configuration:

```sh
source ~/.zshrc
```

## Notes

### Repository Location

This dotfiles repository should be placed in `~/repos/dotfiles` rather than `~/dotfiles` or `~/Documents`. macOS applies stricter privacy controls (TCC) to directories like `~/Documents`, `~/Desktop`, and `~/Downloads`.

Apps—especially sandboxed ones, like Aerospace—must request explicit user permission to access these locations, even if the file path is valid and the file exists. When a config file is symlinked to somewhere inside `~/Documents`, macOS sees it as an access to a protected location and may deny access silently or log it.

Placing `dotfiles` in a less restricted path like `~/repos/dotfiles` avoids these privacy controls, and apps can freely follow symlinks without triggering System Policy denials.

### Custom Location

If you need to use a different location, set the `DOTFILES_TARGET` environment variable before running `install.sh`:

```sh
export DOTFILES_TARGET="/path/to/your/dotfiles"
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
