# npm global tool autoupdate

Operator notes for the daily job that keeps the globally installed npm CLI tools current.

## Why

`home/.zprofile` sets `NPM_CONFIG_PREFIX=$HOME/.npm-global`, and the agent tooling lives there (lavish-axi, quota-axi, gh-axi, chrome-devtools-axi, tasks-axi, pi, prime-agent).
They were installed by hand and nothing updated them, while firstmate keeps raising its minimum versions, so a stale copy shows up as an unavailable tool at session start.

## What runs

| Piece | Path |
| --- | --- |
| Script | `home/.local/bin/npm-global-autoupdate.sh` (linked to `~/.local/bin/` in `home.nix`) |
| Schedule | `home/Library/LaunchAgents/com.scottjrainey.npm-global-autoupdate.plist`, daily 04:30, no `RunAtLoad` |
| Loaded by | `bootstrap.sh` Step 11 (a `darwin-rebuild switch` only places the plist), or logout/login |
| Log | `~/Library/Logs/npm-global-autoupdate.log` (appended, one `---` header per run) |
| Status | `~/.local/state/npm-global-autoupdate/status` |
| Tests | `tests/npm-global-autoupdate.test.sh` |

Mechanism choice: a launchd agent, matching how this repo already schedules jobs, rather than a `darwin-rebuild` hook.
A rebuild hook would only update when a rebuild happens and would run inside an interactive session's shell; the agent runs at an idle hour and is independent of rebuilds.

## Behavior

1. **Defers** (exit 0, status `deferred`) while any process is running out of `~/.npm-global/`, or another run holds the lock. npm swaps package directories in place, which can break a live agent session, so the job waits for the next day instead. A lock dir older than 3 hours (a run killed before cleanup) is treated as stale and taken over. The 3rd consecutive deferral fails instead (see below).
2. Lists installed packages with `npm ls -g`; an empty list fails the run, but a nonzero exit with a usable listing (as `npm ls` gives for tree problems) is tolerated. Checks each installed package against the registry. A package the registry does not know (E404) is **unmanaged**: it is named in the log and status and skipped, because one E404 would otherwise fail `npm update -g` for every tool. `prime-agent` is in this state today and has to be updated the way it was installed. Any other registry error fails the run.
3. `npm update -g` on the managed packages, then `npm outdated -g` must report nothing or the run fails.
4. If any version changed, or no run has ever succeeded, re-runs `<tool> setup hooks` for every installed tool in the known list (gh-axi, lavish-axi, tasks-axi, chrome-devtools-axi, quota-axi, pi, prime-agent) that advertises it. Each candidate is probed with `<tool> setup --help`, killed after 5 seconds; nothing outside the list is executed, so a new tool needs an edit to `KNOWN_TOOLS` in the script. Today the hooks run for gh-axi, lavish-axi, tasks-axi, chrome-devtools-axi. These only write agent hook/plugin config; nothing under `~/.claude/skills` or `~/.agents/skills`.

## Failing visibly

- Status file, one line: `<ok|deferred|failed> <epoch> <iso-time> <message>`. `last-ok` in the same directory exists once a run fully succeeded and is removed by any failure, so the next run re-runs setup hooks.
- A failure exits nonzero, fires a macOS notification, and leaves npm's output in the log.
- A single `deferred` is normal and quiet. The consecutive count lives in `deferrals` in the state dir and resets on any run that is not deferred; the 3rd in a row fails with a notification. That means something is always running out of the prefix (look at `pgrep -fl "$HOME/.npm-global/"`) or the lock is held.

## Running it by hand

```sh
~/.local/bin/npm-global-autoupdate.sh      # same run launchd does
cat ~/.local/state/npm-global-autoupdate/status
npm outdated -g                            # should print nothing
launchctl print gui/$(id -u)/com.scottjrainey.npm-global-autoupdate
```

The setup probe invokes each known tool once with `setup --help`; `pi` creates its `~/.pi/agent` files on any invocation, which already exist on this machine.
