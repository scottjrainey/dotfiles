#!/usr/bin/env bash
# Takes a fresh Mac from a bare clone to an applied nix-darwin config.
# Run this once. After it finishes, use ./rebuild.sh for normal changes.
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
TMP_FILES=()

cleanup() {
  if [ "${#TMP_FILES[@]}" -gt 0 ]; then
    rm -f "${TMP_FILES[@]}"
  fi
}
trap cleanup EXIT

download_to_temp() {
  local url="$1"
  local tmp
  tmp="$(mktemp)"
  TMP_FILES+=("$tmp")
  curl -fsSL "$url" -o "$tmp"
  printf '%s\n' "$tmp"
}

echo "==> Step 1: Determinate Nix"
if command -v nix >/dev/null 2>&1; then
  echo "    nix already installed, skipping"
else
  curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix \
    | sh -s -- install --no-confirm
  # shellcheck disable=SC1091
  . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
fi

echo "==> Step 2: symlink this repo to ~/.dotfiles"
if [ -e "$HOME/.dotfiles" ] && [ ! -L "$HOME/.dotfiles" ]; then
  echo "    $HOME/.dotfiles exists and is not a symlink."
  echo "    Move it aside or link this repo there before continuing."
  exit 1
fi
mkdir -p "$HOME/.local"
ln -sfn "$DIR" "$HOME/.dotfiles"

echo "==> Step 3: personalize the configured username"
REAL_USER="$(whoami)"
FLAKE_USER="$(sed -nE 's/^[[:space:]]*user = "([^"]+)";.*/\1/p' "$DIR/flake.nix" | head -n1)"
if [ -z "$FLAKE_USER" ]; then
  echo "    Could not find the single \"user = \" line in flake.nix."
  echo "    Edit flake.nix before continuing."
  exit 1
elif [ "$FLAKE_USER" != "$REAL_USER" ]; then
  echo "    flake.nix is configured for user \"$FLAKE_USER\", but you are \"$REAL_USER\"."
  read -r -p "    Rewrite flake.nix's \"user = \" line to \"$REAL_USER\"? [y/N] " reply
  if [ "$reply" = "y" ] || [ "$reply" = "Y" ]; then
    sed -i '' -E "s/^([[:space:]]*user = \")[^\"]+(\";.*)/\1${REAL_USER}\2/" "$DIR/flake.nix"
    echo "    Updated flake.nix."
  else
    echo "    Skipped. Edit the single \"user = \" line in flake.nix before continuing."
    exit 1
  fi
else
  echo "    flake.nix already matches \"$REAL_USER\", nothing to do."
fi

echo "==> Step 4: oh-my-zsh and plugins"
if [ ! -d "$HOME/.oh-my-zsh" ]; then
  omz_installer="$(download_to_temp https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
  RUNZSH=no CHSH=no KEEP_ZSHRC=yes sh "$omz_installer"
else
  echo "    oh-my-zsh already installed, skipping"
fi

ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"
mkdir -p "$ZSH_CUSTOM/plugins"
autosuggestions_dir="$ZSH_CUSTOM/plugins/zsh-autosuggestions"
if [ ! -d "$autosuggestions_dir" ]; then
  git clone https://github.com/zsh-users/zsh-autosuggestions "$autosuggestions_dir"
else
  echo "    zsh-autosuggestions already installed, skipping"
fi

echo "==> Step 5: external agent installers"
if ! command -v claude >/dev/null 2>&1; then
  claude_installer="$(download_to_temp https://claude.ai/install.sh)"
  bash "$claude_installer"
else
  echo "    claude already installed, skipping"
fi

if ! command -v pi >/dev/null 2>&1; then
  pi_installer="$(download_to_temp https://pi.dev/install.sh)"
  sh "$pi_installer"
else
  echo "    pi already installed, skipping"
fi

echo "==> Step 6: symlink sibling dotfiles-private to ~/.dotfiles-private"
PRIVATE_DIR="$(cd "$DIR/.." && pwd -P)/dotfiles-private"
if [ -d "$PRIVATE_DIR" ]; then
  if [ -e "$HOME/.dotfiles-private" ] && [ ! -L "$HOME/.dotfiles-private" ]; then
    echo "    $HOME/.dotfiles-private exists and is not a symlink."
    echo "    Move it aside or link the private repo there before continuing."
    exit 1
  fi
  ln -sfn "$PRIVATE_DIR" "$HOME/.dotfiles-private"
  echo "    Linked $PRIVATE_DIR -> $HOME/.dotfiles-private"
else
  echo "    No sibling dotfiles-private checkout found, skipping"
fi

echo "==> Step 7: first darwin-rebuild switch"
NIX_BIN="$(command -v nix)"
cd "$DIR"
sudo "$NIX_BIN" run github:nix-darwin/nix-darwin/nix-darwin-26.05#darwin-rebuild -- \
  switch --flake .#mac --impure

echo "==> Step 8: trust Homebrew taps"
if [ -x /opt/homebrew/bin/brew ]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
fi
if command -v brew >/dev/null 2>&1; then
  while IFS= read -r line; do
    if [[ "$line" =~ ^tap[[:space:]]+\"([^\"]+)\" ]]; then
      brew trust "${BASH_REMATCH[1]}" >/dev/null 2>&1
    fi
  done < "$DIR/Brewfile"

  while IFS= read -r line; do
    if [[ "$line" =~ ^(brew|cask)[[:space:]]+\"([^\"]+/[^\"]+/[^\"]+)\" ]]; then
      case "${BASH_REMATCH[1]}" in
        brew) brew trust --formula "${BASH_REMATCH[2]}" >/dev/null ;;
        cask) brew trust --cask "${BASH_REMATCH[2]}" >/dev/null ;;
      esac
    fi
  done < "$DIR/Brewfile"
else
  echo "    brew not found, skipping tap trust"
fi

echo "==> Step 9: load WhichSpace LaunchAgent"
WHICHSPACE_PLIST="$HOME/Library/LaunchAgents/io.gechr.WhichSpace.plist"
if [ -d /Applications/WhichSpace.app ]; then
  launchctl bootstrap "gui/$(id -u)" "$WHICHSPACE_PLIST" 2>/dev/null \
    || launchctl kickstart -k "gui/$(id -u)/io.gechr.WhichSpace" 2>/dev/null \
    || echo "    WARNING: could not load WhichSpace LaunchAgent"
else
  echo "    WhichSpace.app not found in /Applications, skipping LaunchAgent load"
fi

echo "==> Done. Use ./rebuild.sh for future changes."
