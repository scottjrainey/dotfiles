# Agent Policy

Project-scoped instructions for working in this dotfiles repo.

## Operating rules

- Treat this repository as personal infrastructure. Preserve existing behavior unless a task explicitly asks for a change.
- Prefer small, reviewable edits that match the surrounding style.
- Do not drop configuration, package entries, or local scripts silently. Document intentional removals.
- Read the relevant files before editing them.
- Avoid destructive commands unless the task explicitly calls for them.

## Dotfiles

- Files under `home/` mirror paths in the macOS home directory.
- Home Manager links those files with `mkOutOfStoreSymlink`, so editing a file under `home/` edits the live config target.
- Scott's shell setup is hand-maintained through oh-my-zsh. Preserve `.zshrc`, `.zprofile`, Starship, and related config files as symlinked files instead of generated Home Manager program modules.

## Package management

- `configuration.nix` (`homebrew.taps`/`brews`/`casks`) is authoritative for what gets installed via nix-homebrew.
- `Brewfile` is a second, load-bearing file, not just a historical record: `bootstrap.sh` Step 8 parses it directly to `brew trust` every tap and tap-qualified (`user/tap/name`) formula/cask, which `HOMEBREW_REQUIRE_TAP_TRUST=1` (set in `zprofile`) requires. `brew bundle` has no way to express trust, so this parse step is the only thing that grants it.
- Any tap, or tap-qualified formula/cask, added to or removed from `configuration.nix` must get the matching change in `Brewfile` in the same commit. Skipping this silently breaks tap trust on the next fresh-machine bootstrap, with no error until `brew` refuses the untrusted tap.
- Plain (non-tap-qualified) formulae/casks that only live in Homebrew (e.g. `bat-extras`, `mprocs`, `jqp`, `beads`) should still be mirrored in `Brewfile` for consistency, even though they don't affect tap trust.

## Verification

- Run the narrowest useful check before finishing a change.
- If a check cannot be run locally, state that clearly and explain the remaining risk.
