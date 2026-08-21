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

## Claude Code skills

- Personal Claude Code skills come from `dotfiles-private/claude/skills/` via home-manager, resolving through a Nix store symlink into `~/.claude/skills/<name>`.
- `bootstrap.sh` must not shell out to `npx skills add ... -g` (or otherwise install a skill globally). A prior version did this for `herdr`; it was removed because global skill installs bypass the Nix-managed symlink convention and aren't reproducible across machines.

## Window management (yabai/skhd)

- Helper scripts referenced by `.skhdrc`/`.yabairc` (e.g. `yabai-stack-focus`) live in `home/.local/bin/` when the logic is too non-trivial to duplicate inline across bindings. Reference them by `$HOME/...` path, matching `.skhdrc`'s existing absolute-path convention for the `yabai` binary - skhd's LaunchAgent PATH can't be assumed to include anything beyond system defaults.
- `.skhdrc`'s `alt+ctrl` modifier combo is reserved for window-stacking verbs (cycle/add-to-stack); `alt+ctrl+shift` for the directional add-to-stack bindings. Check there before claiming a new chord.
- To empirically test a `.skhdrc` change without touching the live `skhd`/`yabai` services (never do that - see any task brief's safety rules): skhd's pid-file path is hardcoded to `/tmp/skhd_$USER.pid` with no CLI override, so a second real instance for the same `$USER` always fails to start. Run it with a distinct fake `USER=` env var instead (e.g. `USER=skhd-isotest-$$ skhd -c <scratch-config>`) to get a genuinely isolated process/pid-file. Parse errors print to stdout/stderr as `#<line>:<col> <message>`; a clean config produces no output and the process just keeps running - it won't self-exit, so kill it explicitly rather than `wait`ing on it, and press no keys during the test (a valid config still grabs real global hotkeys in that same login session).
- Stack visual feedback is a transient osascript notification only ("N of M" on cycle/add-to-stack), by deliberate captain decision - not a placeholder for a status bar or border tool. Don't add SketchyBar/JankyBorders/etc. for this unless asked; this was a real, considered choice, not an oversight.

## Scripts and scheduled jobs

- `home/.local/bin/` holds standalone scripts, `home/Library/LaunchAgents/` holds the plists that schedule them, and `docs/` holds each job's operator documentation. Nothing under `home/` is auto-discovered: every file needs its own explicit `home.file` entry in `home.nix`, and a plist also needs `bootstrap.sh` to `launchctl bootstrap` it, because a `darwin-rebuild switch` places a plist without loading it.
- launchd gives a user agent almost no PATH and does not expand variables in plist values. Run the job through `/bin/zsh -l -c` so `$HOME` and the nix/Homebrew PATH resolve at run time; that is also what keeps a machine-specific username out of this public repo.
- `tests/` holds behavior tests, named `<subject>.test.sh` and runnable standalone. `tests/lib.sh` deliberately mirrors the firstmate repo's `tests/lib.sh` helper names and semantics so a test file moves between the two repos unchanged; `FM_BIN_DIR` is the single path difference and it is resolved there, not in each test.
- `home/.local/bin/fm-home-backup.sh` is authored to the firstmate repo's `bin/` conventions (header owns the contract, `set -eu`, real `--help`, fail-closed arguments, shellcheck-clean) because it is expected to move there. It sources firstmate's own `bin/fm-ff-lib.sh` rather than restating the secondmate registry format or the home-safety predicate; keep it that way instead of copying those contracts into this repo.
- `com.scottjrainey.sleepwatcher` (docs/whichspace-wake-reset.md) reacts to sleep/wake via Homebrew's `sleepwatcher`. Its display-only hooks (`-W`/`-D`/`-E`/`-S`) are dead on Apple Silicon - `strings` on the binary shows they're implemented against the legacy `IODisplayWrangler` IOKit service, which doesn't exist on M-series Macs, so they silently never fire. Only `-s`/`-w` (system sleep/wake, via the still-current `IORegisterForSystemPower`) work. Confirmed by live-testing the built agent, not by reading the man page - do the same before trusting any other launchd/IOKit power-notification claim in this repo.

## Verification

- Run the narrowest useful check before finishing a change. For a script under `home/.local/bin/`, that is `shellcheck --norc --external-sources` plus its `tests/<subject>.test.sh`; for a `home.nix` change, `nix flake check --no-build --impure`.
- If a check cannot be run locally, state that clearly and explain the remaining risk.

## Maintaining this file

Keep this file for knowledge useful to almost every future agent session in this project.
Do not repeat what the codebase already shows; point to the authoritative file or command instead.
Prefer rewriting or pruning existing entries over appending new ones.
When updating this file, preserve this bar for all agents and keep entries concise.
