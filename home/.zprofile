# shellcheck shell=bash
# Sourced by zsh as a login-shell dotfile, not executed directly, so it
# intentionally carries no shebang. The directive above just tells shellcheck
# which dialect to lint this POSIX-compatible file as.
eval "$(/opt/homebrew/bin/brew shellenv)"

# brew shellenv's path_helper call rebuilds PATH from /etc/paths(.d), which
# know nothing about nix-darwin and drops it entirely. Re-add the per-user and
# system Nix profile paths - this is where darwin-rebuild and every
# nix-darwin/home-manager-installed package live. Prepend them, in nix-darwin's
# own order, so nix wins over Homebrew and Apple's /usr/bin exactly as it does
# in a scrubbed zsh (where /etc/zshenv resets PATH with no Homebrew at all).
# Otherwise a tool installed by both - e.g. python3, which Homebrew pulls in
# as a dependency - resolves differently in login shells than everywhere else.
export PATH="/etc/profiles/per-user/$USER/bin:/run/current-system/sw/bin:$PATH"

# nix's npm has no writable global-install prefix (it lives under the
# read-only /nix/store package itself). Redirect global installs here instead.
export NPM_CONFIG_PREFIX="$HOME/.npm-global"
export PATH="$PATH:$HOME/.npm-global/bin"

# Opt into Homebrew's upcoming default: only load formulae/casks/commands from
# trusted taps. Third-party taps used by this machine are trusted via `brew
# trust` (stored in ~/.config/homebrew/trust.json) — see Brewfile header.
export HOMEBREW_REQUIRE_TAP_TRUST=1

# Skip auto_updates casks during `brew upgrade` — let apps update themselves.
# Use `brew upgrade --greedy-auto-updates` to force-upgrade them via brew.
export HOMEBREW_NO_UPGRADE_AUTO_UPDATES_CASKS=1
