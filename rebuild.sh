#!/usr/bin/env bash
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
if [ -e "$HOME/.dotfiles" ] && [ ! -L "$HOME/.dotfiles" ]; then
  echo "$HOME/.dotfiles exists and is not a symlink." >&2
  exit 1
fi
ln -sfn "$DIR" "$HOME/.dotfiles"

PRIVATE_DIR="$(cd "$DIR/.." && pwd -P)/dotfiles-private"
if [ -d "$PRIVATE_DIR" ]; then
  if [ -e "$HOME/.dotfiles-private" ] && [ ! -L "$HOME/.dotfiles-private" ]; then
    echo "$HOME/.dotfiles-private exists and is not a symlink." >&2
    exit 1
  fi
  ln -sfn "$PRIVATE_DIR" "$HOME/.dotfiles-private"
fi

cd "$DIR"
exec sudo darwin-rebuild switch --flake .#mac --impure
