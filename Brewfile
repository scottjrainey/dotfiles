# Audit drift between this file and what's actually installed:
#   brew bundle check --verbose                       # listed here but not installed
#   brew bundle cleanup --file=Brewfile --dry-run     # installed but not listed here
#
# HOMEBREW_REQUIRE_TAP_TRUST=1 (set in zprofile) makes Homebrew ignore the
# third-party taps below unless they're trusted. `brew bundle` can't express
# trust, so scripts/install.sh regenerates ~/.config/homebrew/trust.json from
# this file — every tap-qualified (user/tap/name) entry below gets trusted.

tap "anomalyco/tap"
tap "asmvik/formulae"
tap "codecrafters-io/tap"
tap "gechr/tap"
tap "nikitabobko/tap"
tap "supabase/tap"
tap "withgraphite/tap"

# === Terminal, window manager, fonts (human) ===
# UI-facing tools. Agents don't care about these.
cask "ghostty"
cask "cmux"
cask "nikitabobko/tap/aerospace"
brew "asmvik/formulae/yabai"
brew "asmvik/formulae/skhd"
cask "gechr/tap/whichspace"
cask "font-fira-code-nerd-font"
cask "font-iosevka-term-nerd-font"
cask "font-symbols-only-nerd-font"

# === Shells (human) ===
# Interactive shells. Agents run whatever non-interactive shell they're handed.
brew "zsh"
brew "nushell"

# === Shell prompt & interactive helpers (human) ===
# Make the human shell experience nice. Agents run non-interactive shells.
brew "starship"
brew "fzf"
brew "eza"
brew "yazi"

# === Pretty viewers (human) ===
# Visual replacements for cat. Agents read files directly.
brew "bat"
brew "bat-extras"

# === System monitor (human) ===
# TUI process/resource viewer. Agents read /proc-equivalents or ps directly.
brew "btop"

# === Terminal multiplexers (human) ===
brew "tmux"
brew "mprocs"

# === Editor (human, with agent-relevant deps) ===
# neovim is human-driven; luarocks builds nvim plugin natives.
brew "neovim"
brew "luarocks"

# === Search & file finding (human + agent) ===
# Both humans and Claude Code shell out to these constantly.
brew "ripgrep"
brew "fd"

# === Structured data (human + agent) ===
# jq/yq are bread-and-butter for agent shell scripts; jqp is a human TUI.
brew "jq"
brew "yq"
brew "jqp"

# === Git tooling (human + agent) ===
# `git` itself (brewed, not system) plus human-driven UX wrappers.
# Agents call `git`/`gh` directly; humans use lazygit/delta/graphite.
brew "git"
brew "gh"
brew "git-delta"
brew "git-filter-repo"
brew "lazygit"
brew "withgraphite/tap/graphite"

# === HTTP client (human + agent) ===
brew "xh"

# === Network diagnostics (human + agent) ===
brew "nmap"

# === Language runtimes & version managers (human + agent) ===
# Agents run scripts via uv/node; mise is available for project-level pinning.
brew "mise"
brew "uv"
brew "node@22", link: true
npm "corepack"

# === Linting & code quality (human + agent) ===
brew "shellcheck"

# === Task runners (human + agent) ===
# Humans invoke `just <recipe>`; agents follow Justfile recipes.
brew "just"

# === Issue tracking (human) ===
brew "beads"

# === Document & typesetting (human) ===
# tectonic compiles LaTeX; ghostscript handles PostScript/PDF pipeline bits;
# pandoc converts between document formats; poppler renders/extracts PDFs.
brew "tectonic"
brew "ghostscript"
brew "pandoc"
brew "poppler"

# === Containers, cloud & networking (human + agent) ===
# Local container runtime, cloud CLIs, and VPN. Agents shell into these for ops work.
cask "docker-desktop"
cask "gcloud-cli"
cask "tailscale-app"
brew "supabase/tap/supabase"

# === AI desktop apps (human) ===
cask "claude"
cask "codex-app"
cask "cursor"
cask "lm-studio"

# === AI coding agents, CLI (human + agent) ===
# codex is OpenAI's terminal coding agent; codex-app above is the separate
# desktop app. opencode is another terminal-based coding agent.
cask "codex"
brew "anomalyco/tap/opencode"

# === Browser (human) ===
cask "google-chrome"

# === Notes (human) ===
cask "obsidian"

# === Communication (human) ===
cask "discord"
cask "slack"
cask "zoom"

# === Learning (human) ===
brew "codecrafters-io/tap/codecrafters"
