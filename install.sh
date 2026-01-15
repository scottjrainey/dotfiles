#!/usr/bin/env bash
set -euo pipefail

: "${DOTFILES_TARGET:="$HOME/.dotfiles"}"
: "${ZSH_CUSTOM:="$HOME/.oh-my-zsh/custom"}"

# Detect OS
OS="$(uname -s)"

# TODO Check that there are not existing configs that will be destroyed

# Link dotfiles to home directory
CONFIG_DIR="$HOME/.config"
mkdir -p "$CONFIG_DIR/mise"
mkdir -p "$CONFIG_DIR/ripgrep"
mkdir -p "$CONFIG_DIR/tmux"
mkdir -p "$ZSH_CUSTOM/plugins"

# macOS-specific directories
if [[ "$OS" == "Darwin" ]]; then
  mkdir -p "$CONFIG_DIR/aerospace"
  mkdir -p "$CONFIG_DIR/ghostty"
fi

ln -sf "$DOTFILES_TARGET/_mise.toml" "$CONFIG_DIR/mise/config.toml"
ln -sf "$DOTFILES_TARGET/_mise.lock" "$CONFIG_DIR/mise/mise.lock"

# macOS-specific configs
if [[ "$OS" == "Darwin" ]]; then
  ln -sf "$DOTFILES_TARGET/aerospace.toml" "$CONFIG_DIR/aerospace/aerospace.toml"
  ln -sf "$DOTFILES_TARGET/ghostty.config" "$CONFIG_DIR/ghostty/config"
fi

ln -sf "$DOTFILES_TARGET/nvim" "$CONFIG_DIR/nvim"
ln -sf "$DOTFILES_TARGET/ripgreprc" "$CONFIG_DIR/ripgrep/config"
ln -sf "$DOTFILES_TARGET/starship.toml" "$CONFIG_DIR/starship.toml"
ln -sf "$DOTFILES_TARGET/tmux.conf" "$CONFIG_DIR/tmux/tmux.conf"
ln -sf "$DOTFILES_TARGET/zshrc" "$HOME/.zshrc"

for file in "$DOTFILES_TARGET/oh-my-zsh-plugins"/*; do
  ln -sf "$file" "$ZSH_CUSTOM/plugins/"
done

# Link .claude configuration files (runtime data stays in ~/.claude)
mkdir -p "$HOME/.claude/plugins"
ln -sf "$DOTFILES_TARGET/claude/settings.json" "$HOME/.claude/settings.json"
ln -sf "$DOTFILES_TARGET/claude/commands" "$HOME/.claude/"
ln -sf "$DOTFILES_TARGET/claude/plugins/installed_plugins.json" "$HOME/.claude/plugins/installed_plugins.json"
ln -sf "$DOTFILES_TARGET/claude/plugins/known_marketplaces.json" "$HOME/.claude/plugins/known_marketplaces.json"

mkdir -p "$HOME/.local"
ln -sf "$DOTFILES_TARGET/bin" "$HOME/.local/bin"

echo "Dotfiles linked"
