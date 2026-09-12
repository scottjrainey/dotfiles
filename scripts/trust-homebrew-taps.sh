#!/usr/bin/env bash
# Trusts every Homebrew tap, and every tap-qualified (user/tap/name) brew and
# cask, listed in this repo's Brewfile. HOMEBREW_REQUIRE_TAP_TRUST=1 (set in
# home/.zprofile) makes Homebrew refuse to load an untrusted tap's
# casks/formulae, and `brew bundle` has no way to express trust - this is the
# only thing that grants it. See AGENTS.md's "Package management" section.
#
# Shared by bootstrap.sh (Step 8) and rebuild.sh, so a newly-added tap gets
# trusted on an ordinary rebuild too, not only on a fresh-machine bootstrap.
# Safe to re-run: already-trusted taps/formulae/casks are a no-op.
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"

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
