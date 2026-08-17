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

- `home/.local/bin/` holds standalone helper scripts referenced by `.skhdrc`/`.yabairc` (e.g. `yabai-stack-focus`) for logic too non-trivial to duplicate inline across multiple bindings. Reference them by `$HOME/...` path, matching `.skhdrc`'s existing absolute-path convention for the `yabai` binary - skhd's LaunchAgent PATH can't be assumed to include anything beyond system defaults.
- `.skhdrc`'s `alt+ctrl` modifier combo is reserved for window-stacking verbs (cycle/add-to-stack); `alt+ctrl+shift` for the directional add-to-stack bindings. Check there before claiming a new chord.
- To empirically test a `.skhdrc` change without touching the live `skhd`/`yabai` services (never do that - see any task brief's safety rules): skhd's pid-file path is hardcoded to `/tmp/skhd_$USER.pid` with no CLI override, so a second real instance for the same `$USER` always fails to start. Run it with a distinct fake `USER=` env var instead (e.g. `USER=skhd-isotest-$$ skhd -c <scratch-config>`) to get a genuinely isolated process/pid-file. Parse errors print to stdout/stderr as `#<line>:<col> <message>`; a clean config produces no output and the process just keeps running - it won't self-exit, so kill it explicitly rather than `wait`ing on it, and press no keys during the test (a valid config still grabs real global hotkeys in that same login session).
- Stack visual feedback is a transient osascript notification only ("N of M" on cycle/add-to-stack), by deliberate captain decision - not a placeholder for a status bar or border tool. Don't add SketchyBar/JankyBorders/etc. for this unless asked; this was a real, considered choice, not an oversight.

## Verification

- Run the narrowest useful check before finishing a change.
- If a check cannot be run locally, state that clearly and explain the remaining risk.

## Maintaining this file

Keep this file for knowledge useful to almost every future agent session in this project.
Do not repeat what the codebase already shows; point to the authoritative file or command instead.
Prefer rewriting or pruning existing entries over appending new ones.
When updating this file, preserve this bar for all agents and keep entries concise.
