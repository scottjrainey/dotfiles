# dotfiles

Scott's personal macOS setup, managed with nix-darwin, home-manager, and nix-homebrew.
The repo keeps hand-written dotfiles as real files under `home/` and links them into place.

The nix-darwin + home-manager + nix-homebrew structure is based on [Kun Chen's dotfiles](https://github.com/kunchenguid/dotfiles).

## What you get

Running the switch builds:

- macOS defaults for dark mode, keyboard repeat, Dock autohide, Finder, and trackpad tapping.
- Nix CLI packages for shell, editor, search, Git, document tooling, runtimes, and agents' common command-line dependencies.
- Homebrew casks for GUI apps, fonts, and macOS app bundles.
- Homebrew formulae for tapped packages, macOS services, and formulae intentionally left in Homebrew.
- Zsh, oh-my-zsh, autosuggestions, aliases, Starship, fzf, and mise shell integration declared in `home.nix` via Home Manager's `programs.*` modules (no manual install scripts, no symlinked `.zshrc`).
- Neovim, Ghostty, tmux, ripgrep, btop, yabai, skhd, Starship's `starship.toml`, and ccstatusline configs as edit-in-place symlinks.
- One shared `home/AGENTS.md` installed for Claude, Codex, and opencode.

## Prerequisites

- Apple Silicon Mac by default.
- A clone of this repo. `bootstrap.sh` installs Determinate Nix if it is missing.

## Fresh-machine setup

From a bare clone:

```sh
cd dotfiles
./bootstrap.sh
```

`bootstrap.sh` does these steps:

1. Installs Determinate Nix if `nix` is missing.
2. Symlinks this checkout to `~/.dotfiles`.
3. Checks the configured flake user against the current macOS username and offers to rewrite it.
4. Installs Claude Code and Pi if their commands are missing.
5. Symlinks a sibling `dotfiles-private` checkout to `~/.dotfiles-private` if that repo exists.
6. Runs the first `darwin-rebuild switch --flake .#mac --impure`.

oh-my-zsh, zsh-autosuggestions, Starship, fzf, and mise are Nix packages pulled in by `home.nix`'s `programs.*` modules during that switch - no separate install step.

## Daily use

Edit files in this repo, then apply system or package changes:

```sh
./rebuild.sh
```

Most files under `home/` are linked directly into `$HOME`, so changes to shell, editor, terminal, and tool config are visible without a rebuild unless the target symlink itself changes.

## Forking this for yourself

This repo is tailored to Scott's machine, username, and package choices, so it isn't set up as a template for others to reconfigure. To adapt the same nix-darwin/home-manager/nix-homebrew structure for your own setup, start from [Kun Chen's dotfiles](https://github.com/kunchenguid/dotfiles) instead.

## Repo tour

- `flake.nix` wires nixpkgs, nix-darwin, home-manager, and nix-homebrew together.
- `configuration.nix` holds system defaults, nix-homebrew, Homebrew taps, formulae, and casks.
- `home.nix` holds Nix CLI packages, environment variables, shell config (`programs.zsh`, oh-my-zsh, Starship, fzf, mise), and all Home Manager symlinks.
- `home/` mirrors the target home-directory tree.
- `bootstrap.sh` handles first-machine setup.
- `rebuild.sh` reapplies the flake after bootstrap.
- `Brewfile` is not just a historical record: `bootstrap.sh` Step 7 parses it directly to `brew trust` every tap and every tap-qualified formula/cask, which `HOMEBREW_REQUIRE_TAP_TRUST=1` (set in `zprofile`) requires. `configuration.nix` is authoritative for what gets installed, but `Brewfile` must be kept in sync by hand - any tap or tap-qualified formula/cask added to `configuration.nix` needs the matching line added to `Brewfile`, or a fresh-machine bootstrap will fail to trust it.
- `chrome/`, `scripts/*.mjs`, `whichspace/WhichSpaceSettings.json`, and `LICENSE` remain versioned assets outside the symlink tree.

## How the symlinks work

`bootstrap.sh` and `rebuild.sh` link this repo to `~/.dotfiles`.
`home.nix` then uses `mkOutOfStoreSymlink` so targets such as `~/.config/nvim` point at files under `~/.dotfiles/home/.config/nvim`.
This keeps the repo as the source of truth while allowing normal edit-in-place workflows.

The WhichSpace LaunchAgent is installed by symlinking `home/Library/LaunchAgents/io.gechr.WhichSpace.plist` into `~/Library/LaunchAgents`.
The plist is present at login; if immediate loading is needed after a manual edit, use `launchctl` or log out and back in.

`home/.config/aerospace/aerospace.toml` is preserved but not linked.
The old installer had the Aerospace symlink commented out, and `home.nix` keeps that behavior with a commented example line.

## Private dotfiles

`bootstrap.sh` and `rebuild.sh` also link a sibling `dotfiles-private` checkout (if present) to `~/.dotfiles-private`.
If that repo has a `home-module.nix` at its root, `home.nix` imports it automatically — no script to run, no separate install step.
The import is guarded with `builtins.pathExists`, so this flake evaluates and builds cleanly on a machine where the private repo isn't cloned.

This is why every `nix`/`darwin-rebuild` invocation in this repo passes `--impure`: reading a path outside this flake's own source tree (the sibling private checkout) is an impure operation. Without `--impure`, `builtins.pathExists` doesn't error — it silently returns `false`, so the private module would appear absent with no indication why.

`~/.claude/CLAUDE.md`, `~/.codex/AGENTS.md`, and `~/.config/opencode/AGENTS.md` are always owned by this repo (they point at the shared `home/AGENTS.md`). The private module does not declare those paths.

## Notes

CLI tools are biased toward Nix when the nixpkgs attribute is clear.
GUI apps, fonts, tap-qualified packages, macOS services, and uncertain formulae stay in Homebrew.
The three Nerd Font casks stay as Homebrew casks to match the current setup.

`nodejs_22` provides Node 22 and the Corepack command; there is no separate npm-managed `corepack` install in the Nix setup.

Homebrew cleanup warning: `configuration.nix` sets `homebrew.onActivation.cleanup = "zap"`.
On each switch, Homebrew removes packages and casks not listed in `configuration.nix`.
Review the `brews` and `casks` arrays before the first switch.

`.zshrc` is generated by Home Manager from `programs.zsh` in `home.nix` (aliases, oh-my-zsh plugins, autosuggestions, Starship/fzf/mise integration), not symlinked - changing an alias or plugin requires `./rebuild.sh`, unlike the edit-in-place files under `home/`.
`.zprofile` and `starship.toml` remain symlinked dotfiles, edited in place.

## License

This repo is licensed under MIT No Attribution.
See `LICENSE`.
