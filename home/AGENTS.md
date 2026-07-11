# Agent Policy

This file is shared by Claude, Codex, and opencode on Scott's machine.

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

## Verification

- Run the narrowest useful check before finishing a change.
- If a check cannot be run locally, state that clearly and explain the remaining risk.
