# Atuin (shell history)

Atuin replaces zsh's ctrl-r history search with a searchable, SQLite-backed history that records cwd, exit code, and duration per command.

## How it is wired

- The `atuin` binary is a Homebrew formula (`configuration.nix` `brews`, mirrored in `Brewfile`). It comes from homebrew-core, so no tap or `brew trust` is involved.
- `programs.atuin` from Home Manager is deliberately not used. The shell hook, `atuin init zsh`, is hand-written into `programs.zsh.initContent` in `home.nix`, next to mise's activation, guarded by `command -v atuin`.
- The hook rebinds ctrl-r (and the up arrow) to Atuin's UI. It is placed after fzf's integration so Atuin wins ctrl-r; fzf keeps ctrl-t and alt-c.
- `.zshrc` is generated, so run `./rebuild.sh` and open a new shell after the hook changes.

## One-time setup

Atuin works locally with no account. After the first switch, in a new shell:

```sh
atuin import auto   # pull in the existing ~/.zsh_history
```

Optional cross-machine sync needs an account and is not configured here: `atuin register` / `atuin login`, then `atuin sync`. Nothing in this repo stores credentials; Atuin keeps its key and session under `~/.local/share/atuin/` and its database there too. Never add that directory to this public repo.

## Config

Atuin reads `~/.config/atuin/config.toml`, which is not managed here; the defaults are used. Add a symlink entry in `home.nix` (per the AGENTS.md convention) if that changes.

## Upgrading

`darwin-rebuild switch` installs the formula once and does not upgrade it. Run `brew update && brew upgrade atuin`.
