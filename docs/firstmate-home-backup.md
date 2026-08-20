# firstmate home backup

Operator setup and recovery for `fm-home-backup.sh`.

This document owns configuration, scheduling, and recovery procedure.
The command's own header comment and `fm-home-backup.sh --help` own the exact mechanics: what is captured, what is refused and why, the backup repo's layout, every environment variable, and every exit code.
Read `--help` before changing anything here; this file deliberately does not restate it.

## What this protects

Each firstmate home's `data/` directory is durable agent memory - the backlog, learnings, the project and secondmate registries, and one folder per task - and it exists in exactly one place on one disk.
This machine has no Time Machine destination, so nothing else on it is backed up by any system-level mechanism.
`config/` is small and holds per-home operating settings that are equally unrecoverable.
Project clones are not backed up because they come back from their own remotes, and `state/` is not backed up because restoring stale runtime scaffolding is worse than starting clean.

## One-time setup

Creating the backup repository is the captain's action, not an agent's, and nothing runs until it exists.

The firstmate repo is public, so `data/` is gitignored there and must never reach a public remote.
The backup target must therefore be a **private** repository, and `fm-home-backup.sh` refuses to push to anything it cannot positively confirm is private.

    gh repo create <owner>/firstmate-backup --private
    mkdir -p ~/.config/fm-home-backup
    printf '%s\n' '<owner>/firstmate-backup' > ~/.config/fm-home-backup/target
    printf '%s\n' "$HOME/repos/firstmate" > ~/.config/fm-home-backup/home

The `home` file names the primary firstmate home.
It is only consulted when `FM_HOME` is not already set in the environment, which is the case for the scheduled job.
Nothing else is configured, and no path or repository name is hardcoded anywhere in this repository.

Confirm the setup without publishing anything:

    fm-home-backup.sh backup --dry-run

Then take the first real snapshot:

    fm-home-backup.sh backup

## Schedule

The hourly job is `home/Library/LaunchAgents/com.scottjrainey.fm-home-backup.plist`, linked into `~/Library/LaunchAgents` by `home.nix` and loaded by `bootstrap.sh` Step 10.
Like every other file under `home/`, it needs its own explicit `home.file` entry in `home.nix`; there is no auto-discovery.
A `darwin-rebuild switch` places the plist but does not load it, so a newly added or edited agent needs one of:

    launchctl bootstrap "gui/$(id -u)" ~/Library/LaunchAgents/com.scottjrainey.fm-home-backup.plist
    launchctl kickstart -k "gui/$(id -u)/com.scottjrainey.fm-home-backup"

Each run appends one timestamped block to `~/Library/Logs/fm-home-backup.log`.
An unchanged fleet logs a single `no changes` line, so the log grows by a few kilobytes a year and needs no rotation.
Check the last few runs with:

    tail -20 ~/Library/Logs/fm-home-backup.log

The job clones and pushes over HTTPS using `gh` as git's credential helper, which is the same authentication `gh repo view` already needs for the privacy check.
If a scheduled run logs an authentication failure while the same command works in a terminal, confirm that helper is registered:

    gh auth status
    gh auth setup-git

## Recovering after a squall

Restore is per home and always explicit.
Print the plan first; it writes nothing without `--apply`.

    fm-home-backup.sh restore --home main --into /path/to/rebuilt/home
    fm-home-backup.sh restore --home main --into /path/to/rebuilt/home --apply

`--into` must already exist, and a populated `data/` or `config/` there is refused unless `--force` is also given.
Restore never touches `state/` or `projects/` under the destination, so it is safe to run against a live home to recover a single lost tree.

Rebuilding a whole fleet from nothing:

1. Clone the firstmate repo and each secondmate home's checkout as usual.
2. Restore `main` into the primary home.
3. Read `SNAPSHOT` in the backup repo for the list of homes and their original paths, then restore each secondmate home in turn.
4. Re-clone each project listed in the restored `data/projects.md`. Project clone URLs are not captured; see the limitation below.
5. Leave `state/` empty and let firstmate rebuild it.

## Known limitations

- **Project clone URLs are not captured.** `data/projects.md` records each project's name and purpose but not its origin URL, and the only place those URLs exist is inside the clones under `projects/`, which this command is forbidden to read. Recovering them means `gh repo list <owner>` or the captain's own memory. Capturing a clone manifest would require allowing read-only git plumbing against `projects/`, which is a deliberate policy change rather than a code change.
- **Remote secondmate homes are not captured.** A registry record carrying a `host:` field is named in `SNAPSHOT` and on stderr and the run exits non-zero, so a remote home is never silently missed - but it is also never backed up. Back such a home up from its own host until this command grows a remote reader.
- **The backup repo's history is permanent.** A credential that reaches it cannot be removed by deleting the file later, which is why credential-shaped files are refused rather than skipped.

## Verifying a change to the command

    shellcheck --norc --external-sources home/.local/bin/fm-home-backup.sh
    ./tests/fm-home-backup.test.sh

The suite drives the real executable against a throwaway local git remote and a fake `gh`, so it needs no network and no configured target.
It does need a firstmate checkout to copy `bin/fm-ff-lib.sh` and `bin/fm-secondmate-registry-lib.sh` from, because the command sources firstmate's own registry parser and home-safety predicate instead of carrying second copies of them.
The suite looks in `~/repos/firstmate` by default; point it elsewhere with `FM_HOME_BACKUP_TEST_FM_ROOT=/path/to/firstmate ./tests/fm-home-backup.test.sh`.

## If this moves into the firstmate repo

The command is written to firstmate's `bin/` conventions and resolves `FM_ROOT` from its own location first, so dropping it into `bin/fm-home-backup.sh` needs no edit to the command itself.
What is dotfiles-specific is exactly the "Schedule" section above and the `home.nix` and `bootstrap.sh` wiring it describes; everything else in this document travels with the command.
`tests/fm-home-backup.test.sh` moves as-is, because the one path that differs between the two repos - `bin/` versus `home/.local/bin/` - is resolved by `tests/lib.sh` as `FM_BIN_DIR` rather than by the test file.
