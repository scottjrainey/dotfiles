eval "$(/opt/homebrew/bin/brew shellenv)"

# brew shellenv's path_helper call rebuilds PATH from /etc/paths(.d), which
# know nothing about nix-darwin and drops it entirely. Re-add the system and
# per-user Nix profile paths - this is where darwin-rebuild and every
# nix-darwin/home-manager-installed package live.
export PATH="$PATH:/run/current-system/sw/bin:/etc/profiles/per-user/$USER/bin"

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
