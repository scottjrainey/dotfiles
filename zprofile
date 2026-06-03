eval "$(/opt/homebrew/bin/brew shellenv)"

# Opt into Homebrew's upcoming default: only load formulae/casks/commands from
# trusted taps. Third-party taps used by this machine are trusted via `brew
# trust` (stored in ~/.config/homebrew/trust.json) — see Brewfile header.
export HOMEBREW_REQUIRE_TAP_TRUST=1
