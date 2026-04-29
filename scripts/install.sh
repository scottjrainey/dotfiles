#!/usr/bin/env bash
set -euo pipefail

: "${DOTFILES_TARGET:="$HOME/.dotfiles"}"
: "${ZSH_CUSTOM:="$HOME/.oh-my-zsh/custom"}"

# TODO Check that there are not existing configs that will be destroyed

# Link dotfiles to home directory
CONFIG_DIR="$HOME/.config"
mkdir -p "$CONFIG_DIR/ripgrep"
mkdir -p "$CONFIG_DIR/tmux"
mkdir -p "$CONFIG_DIR/aerospace"
mkdir -p "$CONFIG_DIR/ghostty"
mkdir -p "$ZSH_CUSTOM/plugins"

ln -sf "$DOTFILES_TARGET/aerospace.toml" "$CONFIG_DIR/aerospace/aerospace.toml"
ln -sf "$DOTFILES_TARGET/ghostty.config" "$CONFIG_DIR/ghostty/config"
ln -sf "$DOTFILES_TARGET/ccstatusline" "$CONFIG_DIR/ccstatusline"
ln -sf "$DOTFILES_TARGET/nvim" "$CONFIG_DIR/nvim"
ln -sf "$DOTFILES_TARGET/ripgreprc" "$CONFIG_DIR/ripgrep/config"
ln -sf "$DOTFILES_TARGET/starship.toml" "$CONFIG_DIR/starship.toml"
ln -sf "$DOTFILES_TARGET/tmux.conf" "$CONFIG_DIR/tmux/tmux.conf"
ln -sf "$DOTFILES_TARGET/zshrc" "$HOME/.zshrc"

for file in "$DOTFILES_TARGET/oh-my-zsh-plugins"/*; do
  ln -sf "$file" "$ZSH_CUSTOM/plugins/"
done

mkdir -p "$HOME/.local"

# Install Claude Code if not already installed
if ! command -v claude &>/dev/null; then
  curl -fsSL https://claude.ai/install.sh | bash
fi

echo "Dotfiles linked"
