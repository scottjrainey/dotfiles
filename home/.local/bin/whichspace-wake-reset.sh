#!/usr/bin/env sh
# whichspace-wake-reset.sh - force WhichSpace to redraw correctly after the
# display wakes.
#
# THE BUG: after the Mac wakes, WhichSpace's menu bar sometimes collapses
# from the correct 6 lettered blocks (badges B/C/E/N/P/T, per
# whichspace/WhichSpaceSettings.json) down to a single block showing just the
# active space's number. WhichSpace's own unified log confirms it does
# receive the private SkyLight display-wake notification
# (CGSDisplayNotifyProc: got notification kCGSDisplayDidWake) - so the
# process is alive and told about the wake - but whatever it queries for the
# space list/badges right at that moment comes back stale or empty, and
# nothing afterward makes it re-query. Manually toggling WhichSpace's own
# Settings window forces that re-query and instantly fixes the render, with
# no relaunch - confirming this is a stale in-process cache, not a crash or a
# lost private-API connection. There's no upstream fix for this (WhichSpace
# is closed enough, and no sleep/wake issue is open on gechr/WhichSpace as of
# this writing), so this resets the cache the blunt but reliable way: kill
# and let launchd relaunch the process, which always starts with a fresh
# query and never inherits the stale state.
#
# Invoked by the sleepwatcher LaunchAgent
# (home/Library/LaunchAgents/com.scottjrainey.sleepwatcher.plist) as its -w
# (wakeupcommand, IORegisterForSystemPower-backed - see that plist's comment
# for why this is -w and not the display-only -W, which is silently dead on
# Apple Silicon). -w fires on every system wake, including macOS's frequent
# background DarkWake maintenance cycles where the screen never turns on -
# not gating this on display state is deliberate: a DarkWake by definition
# leaves the display off, so a WhichSpace restart during one is never
# visible, and there is no Apple-Silicon-stable IOKit equivalent of
# IODisplayWrangler cheap enough to justify adding just to skip a no-op.

set -eu

WHICHSPACE_LABEL="io.gechr.WhichSpace"

# Nothing to fix if WhichSpace isn't running (not installed, or the user
# quit it) - RunAtLoad already covers normal login startup, and kickstarting
# a job that was never bootstrapped would just fail noisily for no benefit.
pgrep -qx WhichSpace || exit 0

# Give WindowServer a moment to finish settling after the wake notification
# fires - kickstart always starts WhichSpace fresh regardless of timing, but
# a brief pause avoids racing the same private-API staleness this script
# exists to clean up.
sleep 2

exec launchctl kickstart -k "gui/$(id -u)/$WHICHSPACE_LABEL"
