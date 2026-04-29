tap "nikitabobko/tap"

# === Terminal, window manager, fonts (human) ===
# UI-facing tools. Agents don't care about these.
cask "ghostty"
cask "nikitabobko/tap/aerospace"
cask "font-fira-code-nerd-font"
cask "font-iosevka-term-nerd-font"
cask "font-symbols-only-nerd-font"

# === Shell prompt & interactive helpers (human) ===
# Make the human shell experience nice. Agents run non-interactive shells.
brew "starship"
brew "fzf"
brew "eza"

# === Pretty viewers (human) ===
# Visual replacements for cat. Agents read files directly.
brew "bat"
brew "bat-extras"

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

# === Git tooling (human) ===
# Human-driven UX over git. Agents call `git` directly.
brew "lazygit"
brew "git-delta"
brew "gh"

# === HTTP client (human + agent) ===
brew "xh"

# === Language runtimes & version managers (human + agent) ===
# Agents run scripts via uv/node; mise is available for project-level pinning.
brew "mise"
brew "uv"
brew "node@22"

# === Linting & code quality (human + agent) ===
brew "shellcheck"

# === Task runners (human + agent) ===
# Humans invoke `just <recipe>`; agents follow Justfile recipes.
brew "just"

# === Issue tracking (human) ===
brew "beads"
