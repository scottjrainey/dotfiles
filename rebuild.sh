#!/usr/bin/env bash
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
if [ -e "$HOME/.dotfiles" ] && [ ! -L "$HOME/.dotfiles" ]; then
  echo "$HOME/.dotfiles exists and is not a symlink." >&2
  exit 1
fi
ln -sfn "$DIR" "$HOME/.dotfiles"

cd "$DIR"
exec sudo darwin-rebuild switch --flake .#mac
