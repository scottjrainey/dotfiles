#!/usr/bin/env bash
# Loads the npm-global-autoupdate LaunchAgent into the current user's GUI
# launchd domain. See docs/npm-global-autoupdate.md.
#
# Shared by bootstrap.sh (Step 11) and rebuild.sh. A `darwin-rebuild switch`
# only places the plist in ~/Library/LaunchAgents, it does not load it, so
# rebuild.sh calls this after the switch. The plist has no RunAtLoad and this
# never kickstarts, so loading it never starts an update run.
# Safe to re-run: an already-loaded agent is a no-op. Never fails the caller;
# problems are reported as a WARNING line.
set -uo pipefail

LABEL="com.scottjrainey.npm-global-autoupdate"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
DOMAIN="gui/$(id -u)"

if [ ! -f "$PLIST" ]; then
  echo "    plist not linked yet, skipping (re-run bootstrap.sh after a switch)"
  exit 0
fi

launchctl bootstrap "$DOMAIN" "$PLIST" 2>/dev/null \
  || launchctl print "$DOMAIN/$LABEL" >/dev/null 2>&1 \
  || echo "    WARNING: could not load the npm-global-autoupdate LaunchAgent"
exit 0
