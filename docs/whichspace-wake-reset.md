# WhichSpace wake reset

Operator notes for the sleepwatcher-driven fix to WhichSpace's sleep/wake rendering bug.

## Status: `-w` trigger pending its first confirmation on a real full sleep

Everything up to sleepwatcher's own wake callback has been verified live (see "Why `-w`, not `-W`" below): the bug reproduces on a real wake, the script's gating/kickstart logic is tested, and the LaunchAgent loads and runs correctly. What has *not* been directly observed is `-w` itself firing after a genuine full system sleep - testing that would have meant forcing a real `pmset sleepnow` on the live machine while other agent sessions were running, which was escalated rather than done unilaterally (see the PR for the full exchange). The captain decided to ship with this one link unconfirmed rather than force it.
`-w` is backed by the same public `IORegisterForSystemPower` API every other sleep/wake-reactive macOS tool relies on, so it's expected to work - but until it's seen firing for real, treat this fix as unconfirmed end-to-end. If the menu bar still shows the 1-block bug after a wake once this is active, the existing manual workaround still applies: toggle WhichSpace's own menu-bar Settings switch off and back on.

## The bug

After the Mac wakes from sleep, WhichSpace's menu bar sometimes collapses from the correct 6 lettered blocks (badges B/C/E/N/P/T, per `whichspace/WhichSpaceSettings.json`) down to a single block showing just the active space's number.
WhichSpace itself keeps running and stays otherwise fully functional; only the badge/multi-space render is wrong.

## Root cause

`log show --predicate 'process == "WhichSpace"'` around a real wake shows WhichSpace does receive the private SkyLight notification for it (`CGSDisplayNotifyProc: got notification kCGSDisplayDidWake`), so the process is alive and told about the wake.
But whatever it queries for the space list/badges at that moment comes back stale or incomplete, and nothing afterward makes it re-query - the broken render is what stays on screen indefinitely.

The existing manual workaround - toggling WhichSpace's own menu-bar Settings switch off and back on, no relaunch needed - fixes it instantly, which pins this down to a stale in-process cache rather than a crash or a lost connection to WindowServer: opening the Settings window happens to force the same query that a real fix needs to force after every wake.

There is no known upstream fix: no open or recently closed issue on [gechr/WhichSpace](https://github.com/gechr/WhichSpace) covers sleep/wake, and the project doesn't expose the internals needed to replicate the Settings-panel re-query short of scripting a UI click - fragile, and liable to break on any WhichSpace UI update. A full process relaunch sidesteps all of that: it is guaranteed to start with a fresh query every time, with no dependency on WhichSpace's internal implementation.

## The fix

- `home/Library/LaunchAgents/com.scottjrainey.sleepwatcher.plist` runs Homebrew's `sleepwatcher` daemon (`brew "sleepwatcher"` in `Brewfile`/`configuration.nix`) with `-w` (`wakeupcommand`).
- The script is a no-op if WhichSpace isn't running, otherwise waits 2 seconds for WindowServer to settle and runs `launchctl kickstart -k gui/<uid>/io.gechr.WhichSpace`, which kills and lets launchd relaunch WhichSpace fresh.

### Why `-w`, not `-W`

sleepwatcher also has a display-only wake hook, `-W` (`displaywakeupcommand`), which looked like the better fit at first: unlike `-w`, it does not fire for macOS's frequent background DarkWake maintenance cycles, where the screen stays off.
It turned out to be dead on this hardware. `strings` on the installed binary (`/opt/homebrew/opt/sleepwatcher/sbin/sleepwatcher`) shows `-W`/`-D`/`-E`/`-S` are all implemented against the legacy `IODisplayWrangler` IOKit service, and `ioreg -c IODisplayWrangler` confirms that service no longer exists on this Apple Silicon Mac - the registration `-W` depends on has nothing to attach to, so it silently never fires. This was caught by live-testing the built agent, not by reading the man page: a real, non-disruptive `pmset displaysleepnow` cycle produced a genuine `kCGSDisplayWillSleep`/`kCGSDisplayDidWake` pair in WhichSpace's own log, and `-W` still never ran the script.

`-w` is backed by a different, still-current public API (`IORegisterForSystemPower`; confirmed via the same `strings` pass), so it isn't affected.
The tradeoff is that `-w` also fires on background DarkWake, not only a real interactive wake - deliberately left unguarded rather than adding an Apple-Silicon-equivalent display-state check, because a DarkWake by definition leaves the display off, so a WhichSpace restart during one is never visible and therefore never a real regression.

## Activating after merge

`home.nix` only places the plist; loading it needs one of:

    launchctl bootstrap "gui/$(id -u)" ~/Library/LaunchAgents/com.scottjrainey.sleepwatcher.plist
    launchctl kickstart -k "gui/$(id -u)/com.scottjrainey.sleepwatcher"

or a logout/login, or re-running `bootstrap.sh` (Step 11).
A `darwin-rebuild switch` alone (via `./rebuild.sh`) places the plist but does not load it - same as every other LaunchAgent in this repo.

Confirm it's running:

    launchctl print "gui/$(id -u)/com.scottjrainey.sleepwatcher" | head -5

## Verifying a change to the script

    shellcheck --norc --external-sources home/.local/bin/whichspace-wake-reset.sh
    ./tests/whichspace-wake-reset.test.sh

The suite fakes `pgrep`, `sleep` and `launchctl` on `PATH`, so it needs neither a running WhichSpace nor a real wake to check the script's own gating and command logic.

End-to-end confirmation that the real fix works needs an actual system wake, since that's the only thing that reproduces the underlying WhichSpace bug.
Compare WhichSpace's PID/start time (`ps -p "$(pgrep -x WhichSpace)" -o pid,lstart`) before and after a wake - `launchctl kickstart -k` always produces a new PID - and confirm the menu bar shows all 6 badges afterward with no manual toggle.
