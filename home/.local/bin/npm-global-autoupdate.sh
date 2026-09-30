#!/usr/bin/env bash
# Update every globally installed npm CLI tool under ~/.npm-global, then re-run
# the post-install setup those tools need.
# Usage: npm-global-autoupdate.sh [--help]
#
# WHY THIS EXISTS
# NPM_CONFIG_PREFIX points npm's global prefix at ~/.npm-global (home/.zprofile)
# and the tools in it (lavish-axi, quota-axi, gh-axi, chrome-devtools-axi,
# tasks-axi, pi, prime-agent, ...) were installed by hand, so nothing ever
# moved them forward. Firstmate raises its minimum tool versions as it evolves,
# and a stale copy shows up as an "unavailable" tool at session start.
# Invoked daily by com.scottjrainey.npm-global-autoupdate (docs/npm-global-autoupdate.md).
#
# WHAT A RUN DOES
#   1. Defers (exit 0, state "deferred") while any process is running out of
#      the prefix. npm replaces package directories in place, which can pull
#      files out from under a live agent session; waiting for the next
#      scheduled run is cheaper than breaking one.
#   2. Snapshots installed name@version, runs `npm update -g` on every package
#      the registry knows (one that returns E404, like prime-agent today, is
#      set aside and named in the log and status rather than failing the lot),
#      and snapshots again.
#   3. Verifies with `npm outdated -g`: anything still outdated after the
#      update is a failure, not a shrug.
#   4. If any package changed (or no run has ever succeeded), re-runs
#      `setup hooks` for every installed tool that offers it. Tools are found by
#      probing `<tool> setup --help` for a "setup hooks" subcommand instead of a
#      hardcoded list, so a newly installed tool with the same contract is
#      covered without an edit here. The hooks only touch agent settings and
#      plugin files; nothing under ~/.claude/skills or ~/.agents/skills.
#
# FAILING VISIBLY
# Every run ends by writing one line to $STATE_DIR/status:
#   <ok|deferred|failed> <epoch> <iso-time> <message>
# A failure also exits nonzero, fires a macOS notification, and leaves npm's own
# output in the log the LaunchAgent redirects into (~/Library/Logs). A run never
# reports ok when the update, the outdated check, or a setup step failed.
#
# Environment (for tests and unusual layouts; defaults are the real locations):
#   NPM_GLOBAL_PREFIX                prefix to manage (default $HOME/.npm-global)
#   NPM_GLOBAL_AUTOUPDATE_STATE_DIR  status and lock dir
#                                    (default ~/.local/state/npm-global-autoupdate)

set -eu

usage() {
  printf 'Usage: npm-global-autoupdate.sh [--help]\n'
  printf 'Updates global npm tools under the npm prefix and re-runs their setup hooks.\n'
}

case "${1:-}" in
  -h | --help)
    usage
    exit 0
    ;;
  '') : ;;
  *)
    printf 'npm-global-autoupdate.sh: unknown argument: %s\n' "$1" >&2
    usage >&2
    exit 2
    ;;
esac

PREFIX=${NPM_GLOBAL_PREFIX:-$HOME/.npm-global}
STATE_DIR=${NPM_GLOBAL_AUTOUPDATE_STATE_DIR:-$HOME/.local/state/npm-global-autoupdate}
STATUS_FILE="$STATE_DIR/status"
LOCK_DIR="$STATE_DIR/lock"

log() { printf '%s %s\n' "$(date +%Y-%m-%dT%H:%M:%S%z)" "$*"; }

write_status() { # <state> <message>
  local tmp="$STATUS_FILE.tmp.$$"
  printf '%s %s %s %s\n' "$1" "$(date +%s)" "$(date +%Y-%m-%dT%H:%M:%S%z)" "$2" > "$tmp"
  mv "$tmp" "$STATUS_FILE"
}

fail() { # <message>
  log "FAILED: $1" >&2
  write_status failed "$1"
  if command -v osascript > /dev/null 2>&1; then
    osascript -e "display notification \"$1\" with title \"npm-global-autoupdate failed\"" > /dev/null 2>&1 || true
  fi
  exit 1
}

[ -d "$PREFIX" ] || { mkdir -p "$STATE_DIR"; fail "npm prefix $PREFIX does not exist"; }
mkdir -p "$STATE_DIR"

# Single-flight: a still-running earlier update must not be raced.
if ! mkdir "$LOCK_DIR" 2> /dev/null; then
  log "another run holds $LOCK_DIR; deferring"
  write_status deferred "another run holds the lock"
  exit 0
fi
WORK=$(mktemp -d "${TMPDIR:-/tmp}/npm-global-autoupdate.XXXXXX")
cleanup() { rm -rf "$WORK"; rmdir "$LOCK_DIR" 2> /dev/null || true; }
trap cleanup EXIT
trap 'exit 143' INT TERM

export NPM_CONFIG_PREFIX="$PREFIX"
command -v npm > /dev/null 2>&1 || fail "npm not found on PATH"

# Never update underneath a live session. The pattern is the prefix path with a
# trailing slash, which matches both the bin/ symlinks and lib/node_modules/.
if pgrep -f "$PREFIX/" > /dev/null 2>&1; then
  log "processes are running out of $PREFIX; deferring to the next scheduled run"
  write_status deferred "tools in $PREFIX are running"
  exit 0
fi

snapshot() { # <outfile>: sorted name@version per installed global package
  npm ls -g --depth=0 --parseable --long 2> /dev/null | awk -F: 'NR > 1 && $2 != "" { print $2 }' | sort > "$1"
}

log "snapshotting installed packages"
snapshot "$WORK/before" || fail "could not list installed packages"

# A package can be installed from somewhere other than the public registry
# (prime-agent today is not published there), and one E404 makes a bare
# `npm update -g` fail for every package. Those are set aside by name, reported
# loudly in the log and status, and left to be updated however they came in.
# Any other `npm view` failure (offline, registry down) is a real failure.
managed=''
unmanaged=''
while IFS= read -r spec; do
  [ -n "$spec" ] || continue
  name=${spec%@*}
  if view_out=$(npm view "$name" version 2>&1); then
    managed="$managed $name"
  elif printf '%s' "$view_out" | grep -q 'E404'; then
    log "WARNING: $name is not in the npm registry; not managed by this job"
    unmanaged="$unmanaged $name"
  else
    log "$view_out" >&2
    fail "could not query the npm registry for $name"
  fi
done < "$WORK/before"

log "npm update -g$managed"
# shellcheck disable=SC2086 # managed is a space-separated list of package names
[ -z "$managed" ] || npm update -g $managed || fail "npm update -g exited nonzero"

snapshot "$WORK/after" || fail "could not list installed packages after update"

log "npm outdated -g"
if ! outdated=$(npm outdated -g 2>&1); then
  log "$outdated" >&2
  fail "packages still outdated after npm update -g"
fi

changed=0
if ! cmp -s "$WORK/before" "$WORK/after"; then
  changed=1
  log "changed packages:"
  diff "$WORK/before" "$WORK/after" | grep '^[<>]' || true
fi

# last-ok is touched only by a fully successful run, so a first run, or one
# after failures, still re-runs setup even when no package version moved.
prior_ok=0
[ -f "$STATE_DIR/last-ok" ] && prior_ok=1

setup_failed=''
if [ "$changed" = 1 ] || [ "$prior_ok" = 0 ]; then
  for bin in "$PREFIX"/bin/*; do
    [ -x "$bin" ] || continue
    name=$(basename "$bin")
    "$bin" setup --help < /dev/null 2>&1 | grep -q 'setup hooks' || continue
    log "$name setup hooks"
    "$bin" setup hooks < /dev/null || setup_failed="$setup_failed $name"
  done
fi

[ -z "$setup_failed" ] || fail "setup hooks failed for:$setup_failed"

touch "$STATE_DIR/last-ok"
if [ "$changed" = 1 ]; then
  write_status ok "updated; nothing outdated${unmanaged:+; unmanaged (not in registry):$unmanaged}"
else
  write_status ok "already current${unmanaged:+; unmanaged (not in registry):$unmanaged}"
fi
log "done"
