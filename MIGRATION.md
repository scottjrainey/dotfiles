# Migration

This records the one-shot move from `scripts/install.sh` plus `Brewfile` to nix-darwin, home-manager, and nix-homebrew.

## Packages

| Type | Original name | Disposition | Notes |
| --- | --- | --- | --- |
| tap | anomalyco/tap | homebrew tap | Declared in `configuration.nix`. |
| tap | asmvik/formulae | homebrew tap | Declared in `configuration.nix`. |
| tap | codecrafters-io/tap | homebrew tap | Declared in `configuration.nix`. |
| tap | gechr/tap | homebrew tap | Declared in `configuration.nix`. |
| tap | nikitabobko/tap | homebrew tap | Declared in `configuration.nix`. |
| tap | supabase/tap | homebrew tap | Declared in `configuration.nix`. |
| tap | withgraphite/tap | homebrew tap | Declared in `configuration.nix`. |
| cask | ghostty | homebrew cask | GUI terminal app. |
| cask | cmux | homebrew cask | GUI app, kept in Homebrew. |
| cask | nikitabobko/tap/aerospace | homebrew cask | GUI/window manager app from tap. Config preserved but not symlinked. |
| brew | asmvik/formulae/yabai | homebrew brew | macOS window-manager service from tap. |
| brew | asmvik/formulae/skhd | homebrew brew | macOS hotkey service from tap. |
| cask | gechr/tap/whichspace | homebrew cask | GUI app from tap. LaunchAgent plist is linked by Home Manager. |
| cask | font-fira-code-nerd-font | homebrew cask | Font cask kept to match current setup. |
| cask | font-iosevka-term-nerd-font | homebrew cask | Font cask kept to match current setup. |
| cask | font-symbols-only-nerd-font | homebrew cask | Font cask kept to match current setup. |
| brew | zsh | nix attr `zsh` | Shell package only; Home Manager does not generate `.zshrc`. |
| brew | nushell | nix attr `nushell` | CLI shell. |
| brew | starship | nix attr `starship` | Prompt binary only; config remains symlinked. |
| brew | fzf | nix attr `fzf` | CLI fuzzy finder. |
| brew | eza | nix attr `eza` | CLI listing tool. |
| brew | yazi | nix attr `yazi` | CLI file manager. |
| brew | bat | nix attr `bat` | CLI viewer. |
| brew | bat-extras | homebrew brew | Left in Homebrew because the nixpkgs attr shape was not certain. |
| brew | btop | nix attr `btop` | CLI system monitor. |
| brew | tmux | nix attr `tmux` | Terminal multiplexer. |
| brew | mprocs | homebrew brew | Left in Homebrew because the nixpkgs attr was not certain. |
| brew | neovim | nix attr `neovim` | Editor binary only; config remains symlinked. |
| brew | luarocks | nix attr `luarocks` | Neovim plugin native dependency. |
| brew | ripgrep | nix attr `ripgrep` | CLI search. |
| brew | fd | nix attr `fd` | CLI file finder. |
| brew | jq | nix attr `jq` | JSON CLI. |
| brew | yq | nix attr `yq-go` | mikefarah Go yq YAML CLI. |
| brew | jqp | homebrew brew | Left in Homebrew because the nixpkgs attr was not certain. |
| brew | git | nix attr `git` | CLI VCS. |
| brew | gh | nix attr `gh` | GitHub CLI. |
| brew | git-delta | nix attr `delta` | Nixpkgs rename from Homebrew formula name. |
| brew | git-filter-repo | nix attr `git-filter-repo` | Git history rewrite tool. |
| brew | lazygit | nix attr `lazygit` | Git TUI. |
| brew | withgraphite/tap/graphite | homebrew brew | Tap-qualified formula. |
| brew | xh | nix attr `xh` | HTTP CLI. |
| brew | nmap | nix attr `nmap` | Network diagnostics. |
| brew | mise | nix attr `mise` | Runtime manager. |
| brew | uv | nix attr `uv` | Python tooling. |
| brew | node@22 | nix attr `nodejs_22` | Provides Node 22 and Corepack. |
| npm | corepack | provided by nix attr `nodejs_22` | Corepack ships with Node; no separate npm package is installed. |
| brew | shellcheck | nix attr `shellcheck` | Shell linter. |
| brew | just | nix attr `just` | Task runner. |
| brew | beads | homebrew brew | Left in Homebrew because the nixpkgs attr was not certain. |
| brew | tectonic | nix attr `tectonic` | TeX engine. |
| brew | ghostscript | nix attr `ghostscript` | PostScript/PDF tooling. |
| brew | pandoc | nix attr `pandoc` | Document converter. |
| brew | poppler | nix attr `poppler` | PDF utilities. |
| cask | docker-desktop | homebrew cask | GUI app. |
| cask | gcloud-cli | homebrew cask | Homebrew cask retained from current setup. |
| cask | tailscale-app | homebrew cask | GUI app. |
| brew | supabase/tap/supabase | homebrew brew | Tap-qualified formula. |
| cask | claude | homebrew cask | GUI app. |
| cask | codex-app | homebrew cask | GUI app. |
| cask | cursor | homebrew cask | GUI app. |
| cask | lm-studio | homebrew cask | GUI app. |
| cask | codex | homebrew cask | Terminal app distributed as cask in current setup. |
| brew | anomalyco/tap/opencode | homebrew brew | Tap-qualified formula. |
| cask | google-chrome | homebrew cask | GUI app. |
| cask | obsidian | homebrew cask | GUI app. |
| cask | discord | homebrew cask | GUI app. |
| cask | slack | homebrew cask | GUI app. |
| cask | zoom | homebrew cask | GUI app. |
| brew | codecrafters-io/tap/codecrafters | homebrew brew | Tap-qualified formula. |

## Symlinks

| Old install.sh source | New home/ path | home.nix target |
| --- | --- | --- |
| `$DOTFILES_TARGET/btop.conf` | `home/.config/btop/btop.conf` | `.config/btop/btop.conf` |
| `$DOTFILES_TARGET/ccstatusline` | `home/.config/ccstatusline` | `.config/ccstatusline` |
| `$DOTFILES_TARGET/ghostty.config` | `home/.config/ghostty/config` | `.config/ghostty/config` |
| `$DOTFILES_TARGET/nvim` | `home/.config/nvim` | `.config/nvim` |
| `$DOTFILES_TARGET/ripgreprc` | `home/.config/ripgrep/config` | `.config/ripgrep/config` |
| `$DOTFILES_TARGET/starship.toml` | `home/.config/starship.toml` | `.config/starship.toml` |
| `$DOTFILES_TARGET/tmux.conf` | `home/.config/tmux/tmux.conf` | `.config/tmux/tmux.conf` |
| `$DOTFILES_TARGET/skhdrc` | `home/.skhdrc` | `.skhdrc` |
| `$DOTFILES_TARGET/yabairc` | `home/.yabairc` | `.yabairc` |
| `$DOTFILES_TARGET/zprofile` | `home/.zprofile` | `.zprofile` |
| `$DOTFILES_TARGET/zshrc` | `home/.zshrc` | `.zshrc` |
| `$DOTFILES_TARGET/oh-my-zsh-plugins/cli-agents` | `home/.oh-my-zsh/custom/plugins/cli-agents` | `.oh-my-zsh/custom/plugins/cli-agents` |
| `$DOTFILES_TARGET/whichspace/io.gechr.WhichSpace.plist` | `home/Library/LaunchAgents/io.gechr.WhichSpace.plist` | `Library/LaunchAgents/io.gechr.WhichSpace.plist` |
| `$DOTFILES_TARGET/aerospace.toml` | `home/.config/aerospace/aerospace.toml` | commented out: `.config/aerospace/aerospace.toml` |
| `home/AGENTS.md` | `home/AGENTS.md` | `.claude/CLAUDE.md` |
| `home/AGENTS.md` | `home/AGENTS.md` | `.codex/AGENTS.md` |
| `home/AGENTS.md` | `home/AGENTS.md` | `.config/opencode/AGENTS.md` |

## Decisions & risks

- `scripts/install.sh` was replaced by `bootstrap.sh`, `rebuild.sh`, and Home Manager symlinks. It was removed after the symlink list above was reproduced.
- The legacy `Brewfile` is retained as an audit artifact even though nix-homebrew is now authoritative.
- `bootstrap.sh` regenerates Homebrew tap trust from the retained `Brewfile` after the first `darwin-rebuild switch`, preserving `HOMEBREW_REQUIRE_TAP_TRUST=1` behavior for taps and tap-qualified formulae/casks.
- Scott's shell remains hand-managed. No `programs.zsh`, `programs.starship`, `programs.fzf`, `programs.mise`, or `programs.neovim` modules were enabled, so Home Manager does not overwrite the symlinked files.
- WhichSpace uses the Home Manager `home.file` LaunchAgent symlink approach, and `bootstrap.sh` immediately bootstraps or kickstarts the symlinked plist after the first `darwin-rebuild switch` when `/Applications/WhichSpace.app` exists.
- Aerospace was moved to `home/.config/aerospace/aerospace.toml` but remains unmanaged because the old `install.sh` symlink was commented out.
- `bat-extras`, `mprocs`, `jqp`, and `beads` stayed in Homebrew because the exact nixpkgs attributes were not certain enough for a no-network migration.
- Tap-qualified or service packages stayed in Homebrew: `asmvik/formulae/yabai`, `asmvik/formulae/skhd`, `withgraphite/tap/graphite`, `supabase/tap/supabase`, `anomalyco/tap/opencode`, and `codecrafters-io/tap/codecrafters`.
- The three Nerd Font casks stayed in Homebrew to preserve the current installation path and cask behavior.
- `node@22` maps to `nodejs_22`; Corepack is provided by that Node package and documented rather than installed through npm.
- `homebrew.onActivation.cleanup = "zap"` is intentionally preserved. Packages outside `configuration.nix` may be removed on switch.

## Follow-on: private dotfiles as a Home Manager module

`bootstrap.sh` step 6 no longer executes `dotfiles-private/scripts/install.sh` directly. It now symlinks the sibling checkout to `~/.dotfiles-private`, and `home.nix` conditionally imports `~/.dotfiles-private/home-module.nix` if present (`builtins.pathExists`-guarded, so this repo still builds without the private one cloned).

This requires `--impure` on every `nix`/`darwin-rebuild` invocation: this machine has `pure-eval = true` set globally (Determinate Nix), and reading a path outside the flake's own source tree — like the private checkout — is impure. Without `--impure`, `builtins.pathExists` silently returns `false` rather than erroring, so the private module would appear absent with no diagnostic.

`~/.claude/CLAUDE.md`, `~/.codex/AGENTS.md`, and `~/.config/opencode/AGENTS.md` remain permanently owned by this repo's `home.nix`. The private module intentionally does not declare `home.file` entries for those three paths.

`dotfiles-private/scripts/install.sh` is retained for now rather than deleted immediately, mirroring how this repo's own old `scripts/install.sh` was kept until the new mechanism was verified. It should be removed in a follow-up once a real `darwin-rebuild switch --flake .#mac --impure` has been run and confirmed to reproduce parity.

Two live-state conflicts were found on this machine that will block an actual `switch` (not fixed as part of this follow-on, since it only covers build-only verification): `~/.claude/settings.json` has diverged from `dotfiles-private/claude/settings.json` (live `PostToolUse`/`PreToolUse` hooks and a different `effortLevel` aren't in the tracked copy), and `~/.codex/AGENTS.md` is a real empty file that collides with this repo's own `home.file` declaration for that path. Neither `home.file` entry sets `force = true`, so Home Manager will hard-error on these instead of silently discarding local state — that's intentional, but both need reconciling by hand before a real switch will succeed.
