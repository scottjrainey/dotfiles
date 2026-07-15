# This file mirrors the `homebrew` block (taps/brews/casks) in
# configuration.nix, which is authoritative for what actually gets
# installed. The two must be kept in sync by hand — see AGENTS.md.
#
# Audit drift between this file and what's actually installed:
#   brew bundle check --verbose                        # listed here but not installed
#   brew bundle cleanup --file=Brewfile --dry-run       # installed but not listed here
#
# HOMEBREW_REQUIRE_TAP_TRUST=1 (set in zprofile) makes Homebrew ignore the
# third-party taps below unless they're trusted. `brew bundle` can't express
# trust, so bootstrap.sh's Step 8 parses this file directly and runs
# `brew trust` on every tap and every tap-qualified (user/tap/name) brew/cask
# below.

tap "anomalyco/tap"
tap "asmvik/formulae"
tap "codecrafters-io/tap"
tap "nikitabobko/tap"
tap "supabase/tap"
tap "withgraphite/tap"

# === Terminal, window manager, fonts ===
cask "ghostty"
cask "cmux"
cask "nikitabobko/tap/aerospace"
brew "asmvik/formulae/yabai"
brew "asmvik/formulae/skhd"
cask "whichspace"
cask "font-fira-code-nerd-font"
cask "font-iosevka-term-nerd-font"
cask "font-symbols-only-nerd-font"

# === Pretty viewers & process utilities ===
# bat-extras extends bat (nix-managed); mprocs is a process-manager TUI.
brew "bat-extras"
brew "mprocs"

# === Structured data ===
# jqp is a jq TUI companion; jq itself is nix-managed.
brew "jqp"

# === Git tooling ===
brew "withgraphite/tap/graphite"

# === Issue tracking ===
brew "beads"

# === Containers, cloud & networking ===
cask "docker-desktop"
cask "gcloud-cli"
cask "tailscale-app"
brew "supabase/tap/supabase"

# === AI desktop apps ===
cask "claude"
cask "codex-app"
cask "cursor"
cask "lm-studio"

# === AI coding agents, CLI ===
# codex is OpenAI's terminal coding agent; codex-app above is the separate
# desktop app. opencode is another terminal-based coding agent. Both pull in
# ripgrep as a runtime dependency, so it stays brew-installed alongside the
# nix-managed ripgrep even though it's not declared here directly.
cask "codex"
brew "anomalyco/tap/opencode"

# === Browser ===
cask "google-chrome"

# === Notes ===
cask "obsidian"

# === Communication ===
cask "discord"
cask "slack"
cask "zoom"

# === Learning ===
brew "codecrafters-io/tap/codecrafters"
