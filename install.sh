#!/usr/bin/env bash
set -euo pipefail

: "${DOTFILES_TARGET:="$HOME/repos/dotfiles"}"

# TODO Check that there are not existing configs that will be destroyed

# Link dotfiles to home directory
CONFIG_DIR="$HOME/.config"
mkdir -p "$CONFIG_DIR/aerospace"
mkdir -p "$CONFIG_DIR/ghostty"
mkdir -p "$CONFIG_DIR/mise"
mkdir -p "$CONFIG_DIR/ripgrep"
mkdir -p "$CONFIG_DIR/tmux"

ln -sf "$DOTFILES_TARGET/_mise.toml" "$CONFIG_DIR/mise/config.toml"
ln -sf "$DOTFILES_TARGET/_mise.lock" "$CONFIG_DIR/mise/mise.lock"

ln -sf "$DOTFILES_TARGET/aerospace.toml" "$CONFIG_DIR/aerospace/aerospace.toml"
ln -sf "$DOTFILES_TARGET/ghostty.config" "$CONFIG_DIR/ghostty/config"
ln -sf "$DOTFILES_TARGET/nvim" "$CONFIG_DIR/nvim"
ln -sf "$DOTFILES_TARGET/ripgreprc" "$CONFIG_DIR/ripgrep/config"
ln -sf "$DOTFILES_TARGET/starship.toml" "$CONFIG_DIR/starship.toml"
ln -sf "$DOTFILES_TARGET/tmux.conf" "$CONFIG_DIR/tmux/tmux.conf"
ln -sf "$DOTFILES_TARGET/zshrc" "$HOME/.zshrc"

echo "Dotfiles linked"
