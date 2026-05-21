#!/usr/bin/env bash
set -euo pipefail

: "${DOTFILES_TARGET:="$HOME/.dotfiles"}"
: "${ZSH_CUSTOM:="$HOME/.oh-my-zsh/custom"}"

# TODO Check that there are not existing configs that will be destroyed

# Link dotfiles to home directory
CONFIG_DIR="$HOME/.config"
mkdir -p "$CONFIG_DIR/btop"
mkdir -p "$CONFIG_DIR/ghostty"
mkdir -p "$CONFIG_DIR/ripgrep"
mkdir -p "$CONFIG_DIR/tmux"
#mkdir -p "$CONFIG_DIR/aerospace"
mkdir -p "$ZSH_CUSTOM/plugins"

#ln -sf "$DOTFILES_TARGET/aerospace.toml" "$CONFIG_DIR/aerospace/aerospace.toml"
ln -sf  "$DOTFILES_TARGET/btop.conf"      "$CONFIG_DIR/btop/btop.conf"
ln -sfn "$DOTFILES_TARGET/ccstatusline"   "$CONFIG_DIR/ccstatusline"
ln -sf  "$DOTFILES_TARGET/ghostty.config" "$CONFIG_DIR/ghostty/config"
ln -sfn "$DOTFILES_TARGET/nvim"           "$CONFIG_DIR/nvim"
ln -sf  "$DOTFILES_TARGET/ripgreprc"      "$CONFIG_DIR/ripgrep/config"
ln -sf  "$DOTFILES_TARGET/starship.toml"  "$CONFIG_DIR/starship.toml"
ln -sf  "$DOTFILES_TARGET/tmux.conf"      "$CONFIG_DIR/tmux/tmux.conf"
ln -sf  "$DOTFILES_TARGET/skhdrc"         "$HOME/.skhdrc"
ln -sf  "$DOTFILES_TARGET/yabairc"        "$HOME/.yabairc"
ln -sf  "$DOTFILES_TARGET/zprofile"       "$HOME/.zprofile"
ln -sf  "$DOTFILES_TARGET/zshrc"          "$HOME/.zshrc"

# -n on dir links keeps re-runs from nesting (otherwise the second run
# follows the existing symlink and creates a link inside it).
for file in "$DOTFILES_TARGET/oh-my-zsh-plugins"/*; do
  ln -sfn "$file" "$ZSH_CUSTOM/plugins/$(basename "$file")"
done

# Third-party oh-my-zsh plugins referenced by zshrc but not authored here.
# Cloned directly into $ZSH_CUSTOM/plugins/ — oh-my-zsh's native location —
# rather than vendored into this repo. Existing checkouts are left alone;
# a failed clone emits a warning and install proceeds.
ZSH_PLUGINS_THIRD_PARTY=(
  "https://github.com/zsh-users/zsh-autosuggestions"
)
for url in "${ZSH_PLUGINS_THIRD_PARTY[@]}"; do
  name="$(basename "$url" .git)"
  dest="$ZSH_CUSTOM/plugins/$name"
  if [ ! -d "$dest" ]; then
    echo "Cloning oh-my-zsh plugin: $name"
    git clone "$url" "$dest" \
      || echo "WARNING: could not clone $name (plugin may not load)"
  fi
done

mkdir -p "$HOME/.local"

# Install Claude Code if not already installed
if ! command -v claude &>/dev/null; then
  curl -fsSL https://claude.ai/install.sh | bash
fi

echo "Dotfiles linked"

# Dispatch into the private dotfiles repo if it's checked out as a sibling
# of this one. Silently skips when absent so the public installer remains
# usable on fresh machines before the private repo is cloned.
PRIVATE_DIR="$(cd "$DOTFILES_TARGET/.." 2>/dev/null && pwd)/dotfiles-private"
if [ -x "$PRIVATE_DIR/scripts/install.sh" ]; then
  echo "Found private dotfiles at $PRIVATE_DIR — running"
  DOTFILES_PRIVATE_TARGET="$PRIVATE_DIR" bash "$PRIVATE_DIR/scripts/install.sh"
fi
