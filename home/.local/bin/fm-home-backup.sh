#!/usr/bin/env bash
# Back up every firstmate home's irreplaceable local material to one private git
# repo, and restore a single home out of it.
# Usage: fm-home-backup.sh backup [--dry-run]
#        fm-home-backup.sh restore --home <id> --into <dir> [--apply] [--force]
#        fm-home-backup.sh --help
#
# WHAT IS CAPTURED, AND WHY IT IS AN ALLOWLIST
# Exactly two top-level trees per home: data/ and config/. Nothing else. This is
# an allowlist and never a denylist: a new private file dropped anywhere else in
# a home (.env, a token file, a scratch export) is excluded because it was never
# named, not because a pattern happened to catch it. state/ is runtime
# scaffolding and restoring a stale copy is worse than starting clean; projects/
# is re-clonable from its own remotes; both are simply not on the list.
# Inside data/ and config/ a second, narrower guard refuses (never silently
# skips) credential-shaped files - see CREDENTIAL SHAPES below.
#
# LAYOUT IN THE BACKUP REPO
#   README.md            tool-owned, regenerated every run, safe to read first
#   SNAPSHOT             which homes this fleet has, and which were not captured
#   <home-id>/MANIFEST   one line per captured directory and file, with modes
#   <home-id>/data/...   verbatim copy
#   <home-id>/config/... verbatim copy
# The primary home is always the id "main"; every secondmate uses its registry
# id. A registered secondmate named "main" is refused rather than merged.
# Nothing written by this tool carries a timestamp, so an unchanged fleet
# produces a byte-identical tree and therefore no commit and no push. Directories
# and file modes live in MANIFEST because git stores neither, so an empty task
# folder and a 0600 config file both survive the round trip.
#
# HOME DISCOVERY
# The primary home is FM_HOME, and it is never skippable: an FM_HOME that is not
# a usable primary home refuses the whole run. Secondmates are read from that
# home's data/secondmates.md through firstmate's own registry parser and binding
# validator (bin/fm-secondmate-registry-lib.sh via bin/fm-ff-lib.sh), so adding a
# secondmate later needs no edit here and a malformed or overlapping registry is
# refused instead of half-read. Exactly two per-secondmate exceptions are
# reported rather than fatal, so that a squall never finds zero backups because
# one home was unreachable: a remote record (host:) is NOT supported by this
# version and is recorded as unsupported-remote, and a local record whose home
# fails firstmate's own home-safety predicate is recorded as uncaptured-home
# carrying that predicate's reason. In both cases every other home is still
# captured and pushed, the missed home is named on stderr and in SNAPSHOT, and
# the run exits 3; neither is ever silently skipped. Every other registry
# problem - malformed line, failed binding validation, a symlinked registry, an
# id colliding with the primary - still refuses the whole run.
# That skip has one sharp edge, and it is decided by WHERE the failure is
# detected rather than by how bad it is. The two tiers, side by side:
#   leaf missing, parent resolvable   SKIPPED. A registered local home whose own
#     directory is gone or renamed, or which is present but is not a usable
#     seeded secondmate home, fails the per-home predicate in this command's own
#     loop. It is recorded as uncaptured-home, every other home is captured and
#     pushed, and the run exits 3.
#   parent path unresolvable          REFUSES THE WHOLE RUN, exit 1, nothing
#     pushed. The canonical case is an unmounted volume, where macOS removes the
#     whole /Volumes/<name> tree, so even the home's parent directory no longer
#     resolves. firstmate's shared registry binding validator cannot key that
#     record and rejects the registry as a whole, which happens before this
#     command's per-home loop is ever reached, so the skip above cannot apply.
# The second tier is a known limitation inherited from the shared validator, not
# a decision made here; widening it belongs in the firstmate repo, not in this
# command. See docs/firstmate-home-backup.md.
#
# TARGET RESOLUTION, AND WHY IT IS NOT INSIDE A HOME
#   <config-dir>/target   a GitHub owner/repo slug, required
#   <config-dir>/home     absolute path of the primary firstmate home, optional
# config-dir is FM_HOME_BACKUP_CONFIG, else $XDG_CONFIG_HOME/fm-home-backup, else
# ~/.config/fm-home-backup. The target lives there rather than in a home's
# config/ for two reasons: it is read before any home is resolved and never from
# inside one, so no home - correctly or incorrectly resolved - can redirect a
# push; and a restore onto a blank machine has to find the repo when no home
# exists yet. There is no default target and no
# inference from a remote, a hostname, or a sibling clone: an unconfigured target
# refuses and prints the exact setup commands.
#
# TARGET PRIVACY
# The push URL is not configured and not parsed out of the slug; it is whatever
# `gh repo view <slug>` reports as its clone URL. The repo whose privacy was just
# verified is therefore the same object that is pushed to. That URL is gh's HTTPS
# form deliberately: git then authenticates through the same gh credential the
# privacy check already had to satisfy, so a headless run depends on exactly one
# credential instead of a gh token for the check and an SSH agent for the push.
# `gh auth setup-git` is what registers that helper. A push proceeds only
# when that same payload reports BOTH isPrivate=true AND visibility=PRIVATE and
# the returned nameWithOwner matches the configured slug; anything else - public,
# internal, missing field, unauthenticated gh, network failure - refuses without
# pushing. A network failure is the one refusal that exits 75 rather than 1 (see
# NETWORK BOUNDS): it still pushes nothing, it is only classified as temporary.
# Restore deliberately does NOT gate on privacy: it only reads, and
# refusing to restore during a real outage because a repo's visibility drifted
# would help nobody. Restore prints the visibility it saw instead.
#
# READ-ONLY BOUNDARY
# `backup` never writes inside any firstmate home and never reads anything under
# projects/. Its only writes are to the work dir (FM_HOME_BACKUP_WORKDIR, else
# $XDG_CACHE_HOME/fm-home-backup, else ~/.cache/fm-home-backup), which is
# deliberately outside every home so a home stays untouched. `restore` is the
# only path that writes into a home, and it writes only the data/ and config/
# trees under the directory named by --into; state/ and projects/ there are never
# read, moved, or deleted.
#
# CREDENTIAL SHAPES
# A file inside data/ or config/ whose name is dotenv, private-key, or
# credential-store shaped stops the run with the offending path. It is a refusal
# and not a skip, so the choice of leaving it out of the backup is always made
# deliberately by a person. Remediation is either moving the file out of data/
# and config/, or acknowledging it by adding the exact "<home-id>/<relpath>" line
# the refusal prints to <config-dir>/ack.
#
# IDEMPOTENCE AND CONCURRENCY
# Each run resets the work-dir clone hard to origin and rebuilds every captured
# home from scratch, so an interrupted run leaves no partial state anywhere the
# next run can inherit: nothing is published until one commit and one push at the
# end. A second concurrent `backup` takes no action and exits 0 - a scheduled
# overlap is not a failure. `restore` under that same lock instead refuses
# non-zero naming the lock and the pid holding it, for the plan form as much as
# for --apply, because a recovery that quietly did nothing is the one outcome an
# operator must never read as success. The lock records its owner's pid and start
# time and is broken automatically when that process is gone, so a killed run
# cannot wedge every future backup; a lock whose owner record is missing or
# unreadable counts as held for a short grace window, so the instant between
# creating the lock and recording its owner cannot hand one clone to two runs,
# and a genuinely torn lock still self-heals once that window passes.
#
# NETWORK BOUNDS, AND WHY A STALLED NETWORK IS NOT A FAILURE
# This runs on a laptop that sleeps. A call in flight when the machine sleeps
# wakes up holding a dead TCP connection that neither gh nor git notices for many
# minutes, so every network call - the gh privacy check, git clone, fetch and
# push - is bounded:
#   - each attempt is cut off after FM_HOME_BACKUP_NET_TIMEOUT seconds (default
#     10). The bound is enforced in plain bash: the call runs in its own process
#     group and a watchdog kills that whole group, so a helper such as
#     git-remote-https cannot outlive it, and nothing beyond stock macOS (no
#     coreutils timeout) is needed;
#   - git additionally aborts a transfer slower than GIT_HTTP_LOW_SPEED_LIMIT
#     bytes/s for GIT_HTTP_LOW_SPEED_TIME seconds (defaults 1000 and 10, each kept
#     if already set), and never prompts for credentials;
#   - the whole run spends at most FM_HOME_BACKUP_NET_BUDGET seconds of wall
#     time (default 25) on the gh privacy check, which keeps that check inside
#     the watcher's 30s per-check bound. git clone, fetch and push move data, so
#     they are bound by the stall detector above plus a wall ceiling of
#     FM_HOME_BACKUP_TRANSFER_TIMEOUT seconds (default 600) per attempt, and
#     neither the short per-attempt bound nor the budget cuts off a slow but
#     flowing transfer. A run whose budget is already gone - typically because
#     the machine slept part way through - stops before the next call.
# A call that timed out or failed with a network-shaped error is retried exactly
# once after FM_HOME_BACKUP_RETRY_PAUSE seconds (default 3). An attempt whose
# wall time far exceeded its bound means the machine slept during it, so that
# retry also gets a fresh budget: one retry after a wake. Failures that are
# answers rather than silence - an authentication error, a repo gh cannot find,
# a public target - are never retried and keep exiting 1.
# When the retry fails too or the budget runs out, the run exits 75
# (EX_TEMPFAIL) naming what it could not reach, and nothing is published. A run
# sent SIGTERM exits 75 too; a push is atomic, so nothing is ever half-published.
# Either way the next run re-syncs from origin and starts over. A caller should treat 75 as neutral - a skipped
# run - and never count it toward a failure threshold.
#
# UNEXPECTED SHAPES ARE REFUSALS
# A symlink, a non-regular file, or a path containing a tab or newline anywhere
# inside a captured tree stops the run naming the path. So does a backup repo
# whose .gitignore would have excluded a staged file, which is the one way this
# tool could otherwise report success while quietly storing less than it claimed.
#
# RESTORE
# restore requires both --home and --into and prints the full placement plan -
# every mode and every destination path - before doing anything. Without --apply
# it prints that plan and stops. --into must already exist, and a populated
# data/ or config/ there is refused unless --force is also given. The recorded
# original path is never used as an implicit destination: after a squall a home
# is often not where it was, and a "successful" restore into the wrong directory
# is worse than a loud refusal.
# Nothing read out of MANIFEST is trusted. A tree name outside the captured
# allowlist, a mode that is not octal, and a relative path that is absolute,
# carries a "." or ".." component, or is not rooted in one of that manifest's own
# captured trees are each a refusal naming the offending entry, so a manifest can
# only ever describe writes inside --into's data/ and config/.
# --apply stages every tree in one scratch directory inside the destination
# (.fm-home-backup-restore), then for each tree renames the existing tree into
# that scratch and renames the staged tree into its place. Both are
# same-filesystem renames, so no tree is ever half-written even when --into is on
# another disk, and the previous copies are removed only after the whole restore
# has been verified. An interrupted apply therefore leaves
# .fm-home-backup-restore behind holding the previous trees, and the next restore
# refuses until that rescue copy has been dealt with rather than overwriting it.
# A home that SNAPSHOT records as uncaptured-home still has its last successful
# capture in the repo, because a skipped home is deliberately never wiped. The
# plan therefore opens with a prominent warning naming that reason and saying the
# files are of unknown age, and --apply repeats it on stderr as its last word.
# This is a warning and never a refusal: during a real outage, stale memory beats
# no memory, and the operator is the one who gets to weigh that.
#
# ENVIRONMENT
#   FM_HOME                  primary firstmate home (overrides <config-dir>/home)
#   FM_ROOT_OVERRIDE         firstmate repo root supplying bin/fm-ff-lib.sh
#   FM_HOME_BACKUP_CONFIG    operator config dir
#   FM_HOME_BACKUP_WORKDIR   work dir holding the backup clone and the lock
#   FM_HOME_BACKUP_NET_TIMEOUT   seconds one network attempt may take (default 10)
#   FM_HOME_BACKUP_NET_BUDGET    wall seconds the run may spend on network calls
#                                (default 25)
#   FM_HOME_BACKUP_TRANSFER_TIMEOUT  wall ceiling per git transfer attempt
#                                (default 600)
#   FM_HOME_BACKUP_RETRY_PAUSE   seconds between a failed attempt and its one
#                                retry (default 3; 0 is allowed)
#   GIT_HTTP_LOW_SPEED_LIMIT, GIT_HTTP_LOW_SPEED_TIME   git's stall detector,
#                                defaulted to 1000 bytes/s over 10s when unset
#
# EXIT STATUS
#   0  captured and pushed, clean no-op, or a plan-only restore
#   1  refusal or failure; nothing was pushed. A restore blocked by another run's
#      lock lands here, so it can never read as a completed recovery, and so does
#      a registered local home whose parent path cannot be resolved at all - an
#      unmounted volume - which the shared binding validator rejects before any
#      home is captured
#   2  invalid use
#   3  every capturable home was captured and pushed, but at least one registered
#      home was missed: a remote home this version cannot read, or a local home
#      whose own directory is missing or is not a usable secondmate home
#  75  temporary, the run did not complete: GitHub could not be reached within
#      the network bounds even after one retry, or the run's network budget ran
#      out (typically a sleep mid-run) - in both cases nothing was pushed - or
#      the run was sent SIGTERM, which never leaves anything half-published. A
#      privacy check that could not reach GitHub lands here and still refuses to
#      push. Treat it as a skipped run, not a failure; the next run retries from
#      scratch
set -eu

usage() {
  awk 'NR == 1 { next } /^#/ { sub(/^# ?/, ""); print; next } { exit }' "$0"
}

die() {
  printf 'fm-home-backup: %s\n' "$1" >&2
  exit "${2:-1}"
}

# --- argument parsing -------------------------------------------------------
#
# Every branch below either consumes a flag it knows or exits 2. There is no
# trailing "assume the rest is a path" fallback, so a typo can never be absorbed
# as a value.

MODE=
DRY_RUN=0
RESTORE_ID=
RESTORE_INTO=
APPLY=0
FORCE=0

case "${1:-}" in
  -h | --help)
    usage
    exit 0
    ;;
  backup | restore)
    MODE=$1
    shift
    ;;
  '')
    usage >&2
    exit 2
    ;;
  *)
    printf 'fm-home-backup: unknown command: %s\n' "$1" >&2
    usage >&2
    exit 2
    ;;
esac

if [ "$MODE" = backup ]; then
  while [ "$#" -gt 0 ]; do
    case $1 in
      --dry-run)
        [ "$DRY_RUN" -eq 0 ] || die 'repeated --dry-run' 2
        DRY_RUN=1
        shift
        ;;
      *)
        printf 'fm-home-backup: unknown backup option: %s\n' "$1" >&2
        usage >&2
        exit 2
        ;;
    esac
  done
else
  while [ "$#" -gt 0 ]; do
    case $1 in
      --home)
        [ "$#" -ge 2 ] || die '--home needs a home id' 2
        [ -z "$RESTORE_ID" ] || die 'repeated --home' 2
        RESTORE_ID=$2
        shift 2
        ;;
      --into)
        [ "$#" -ge 2 ] || die '--into needs a directory' 2
        [ -z "$RESTORE_INTO" ] || die 'repeated --into' 2
        RESTORE_INTO=$2
        shift 2
        ;;
      --apply)
        [ "$APPLY" -eq 0 ] || die 'repeated --apply' 2
        APPLY=1
        shift
        ;;
      --force)
        [ "$FORCE" -eq 0 ] || die 'repeated --force' 2
        FORCE=1
        shift
        ;;
      *)
        printf 'fm-home-backup: unknown restore option: %s\n' "$1" >&2
        usage >&2
        exit 2
        ;;
    esac
  done
  [ -n "$RESTORE_ID" ] || die 'restore needs --home <id>' 2
  [ -n "$RESTORE_INTO" ] || die 'restore needs --into <dir>' 2
  case $RESTORE_ID in
    *[!A-Za-z0-9._-]*) die "invalid home id: $RESTORE_ID" 2 ;;
  esac
  case $RESTORE_INTO in
    /*) ;;
    *) die "--into must be an absolute path, got: $RESTORE_INTO" 2 ;;
  esac
fi

# --- network bounds ---------------------------------------------------------
#
# Validated before anything else runs, so a mistyped knob is invalid use rather
# than an unbounded or instantly-expiring network call.

EX_TEMPFAIL=75

net_knob() { # <name> <default> <minimum>
  local value
  eval "value=\${$1:-\$2}"
  case $value in
    '' | *[!0-9]*) die "$1 must be a whole number of seconds, got: $value" 2 ;;
  esac
  [ "$value" -ge "$3" ] || die "$1 must be at least $3, got: $value" 2
  printf '%s\n' "$value"
}

NET_TIMEOUT=$(net_knob FM_HOME_BACKUP_NET_TIMEOUT 10 1)
NET_BUDGET=$(net_knob FM_HOME_BACKUP_NET_BUDGET 25 1)
RETRY_PAUSE=$(net_knob FM_HOME_BACKUP_RETRY_PAUSE 3 0)
TRANSFER_TIMEOUT=$(net_knob FM_HOME_BACKUP_TRANSFER_TIMEOUT 600 1)
# An attempt whose wall time overran its bound by more than this slept part way
# through: the watchdog's sleep stops with the machine, the wall clock does not.
WAKE_SLACK=5

export GIT_HTTP_LOW_SPEED_LIMIT=${GIT_HTTP_LOW_SPEED_LIMIT:-1000}
export GIT_HTTP_LOW_SPEED_TIME=${GIT_HTTP_LOW_SPEED_TIME:-10}
export GIT_TERMINAL_PROMPT=0
export GH_PROMPT_DISABLED=1

NET_DEADLINE=$(($(date +%s) + NET_BUDGET))

# Run a command with a wall-clock bound; exits 124 when the bound cut it off.
# It is a subshell so that its job control and traps never leak into the script.
# The command gets its own process group (set -m), so the watchdog can kill the
# whole group - a git-remote-https helper holding the output pipe open would
# otherwise keep the caller's command substitution waiting on a dead connection.
# stdin is /dev/null because a background process group that reads the terminal
# is stopped rather than failed.
# Whether the bound fired is recorded in a marker file the watchdog writes BEFORE
# it kills anything, rather than read from the watchdog's exit status: a command
# can die of that kill before the watchdog gets to exit, and reaping the
# watchdog at that instant would misreport a timeout as an ordinary failure.
# shellcheck disable=SC2317,SC2329 # The trap bodies are reached only by signal.
run_bounded() ( # <seconds> <command...>
  # A kill aimed at a process group that already exited fails, which is
  # expected here and must not end this subshell through the caller's set -e.
  set +e
  secs=$1
  shift
  marker=$(mktemp "$WORKDIR/net.XXXXXX") || {
    printf 'could not create a timeout marker under %s\n' "$WORKDIR" >&2
    exit 1
  }
  pid=
  wd=
  trap 'rm -f -- "$marker"' EXIT
  trap '[ -z "$pid" ] || kill -KILL -- "-$pid" 2> /dev/null; [ -z "$wd" ] || kill -KILL -- "-$wd" 2> /dev/null; exit 143' TERM INT HUP
  set -m
  "$@" < /dev/null &
  pid=$!
  (
    sleep "$secs"
    printf 'fired\n' > "$marker"
    kill -TERM -- "-$pid"
    sleep 2
    kill -KILL -- "-$pid"
  ) > /dev/null 2>&1 &
  wd=$!
  set +m
  rc=0
  wait "$pid" || rc=$?
  kill -KILL -- "-$wd" 2> /dev/null
  wait "$wd" 2> /dev/null
  [ "$rc" -ne 0 ] || exit 0
  if [ -s "$marker" ]; then
    # Anything of the command's group still alive ignored the TERM.
    kill -KILL -- "-$pid" 2> /dev/null
    exit 124
  fi
  exit "$rc"
)

# Whether a failed call's output reads as the network failing rather than as an
# answer. Answers are checked first, so an authentication error that git follows
# with "the remote end hung up" is still a refusal and never retried.
net_transient() { # <exit-status> <output>
  local text
  [ "$1" -ne 124 ] || return 0
  text=$(lower "$2")
  case $text in
    *'authentication failed'* | *'bad credentials'* | *'repository not found'* \
      | *'could not resolve to a repository'* | *'permission denied'* \
      | *'permission to '*' denied'* | *'http 401'* | *'http 403'* | *'http 404'* \
      | *'gh auth login'*)
      return 1
      ;;
    *'could not resolve host'* | *'could not resolve proxy'* | *'no such host'* \
      | *'failed to connect'* | *"couldn't connect"* | *'error connecting to'* \
      | *'connection timed out'* | *'operation timed out'* | *'i/o timeout'* \
      | *'connection reset'* | *'connection refused'* | *'connection was reset'* \
      | *'network is unreachable'* | *'no route to host'* | *'network is down'* \
      | *'operation too slow'* | *'rpc failed; curl'* | *'early eof'* \
      | *'remote end hung up'* | *'unexpected eof'* | *'broken pipe'* \
      | *'tls handshake'* | *'ssl_error'* | *'ssl_read'* | *'ssl_connect'* \
      | *'empty reply from server'* | *'temporary failure in name resolution'* \
      | *'context deadline exceeded'* | *'dial tcp'*)
      return 0
      ;;
  esac
  return 1
}

net_tempfail() { # <what> <why>
  printf 'fm-home-backup: %s: %s\n' "$1" "$2" >&2
  die "nothing was pushed. This is temporary - usually the machine sleeping or the network dropping - and the next run retries from scratch." "$EX_TEMPFAIL"
}

# Run one network call under the bounds above, retrying once. On success, or on
# a failure that is an answer rather than silence, it returns the call's status
# with its combined output in NET_OUT for the caller to report. A call that
# stays silent through its retry, or a run out of budget, exits 75 here.
NET_OUT=
NET_TRANSFER=0
net_call() { # <what> <command...>
  local what=$1 attempt=1 now remaining bound rc ended
  shift
  while :; do
    now=$(date +%s)
    if [ "$NET_TRANSFER" -eq 1 ]; then
      bound=$TRANSFER_TIMEOUT
    else
      remaining=$((NET_DEADLINE - now))
      [ "$remaining" -gt 0 ] \
        || net_tempfail "$what" "the run's ${NET_BUDGET}s network budget ran out before this call (the machine most likely slept mid-run)"
      bound=$NET_TIMEOUT
      [ "$remaining" -ge "$bound" ] || bound=$remaining
    fi
    rc=0
    NET_OUT=$(run_bounded "$bound" "$@" 2>&1) || rc=$?
    [ "$rc" -ne 0 ] || return 0
    net_transient "$rc" "$NET_OUT" || return "$rc"
    ended=$(date +%s)
    if [ "$attempt" -ge 2 ]; then
      if [ "$rc" -eq 124 ]; then
        net_tempfail "$what" "no response within ${bound}s, twice"
      fi
      net_tempfail "$what" "network error, twice:
$NET_OUT"
    fi
    if [ "$NET_TRANSFER" -eq 0 ] && [ "$((ended - now))" -gt "$((bound + WAKE_SLACK))" ]; then
      # The clock jumped past the bound while the watchdog slept with the
      # machine: this attempt straddled a sleep, and its stale connection is
      # exactly what the retry is for. It gets a full budget of its own.
      NET_DEADLINE=$((ended + RETRY_PAUSE + NET_BUDGET))
      printf 'fm-home-backup: %s: the machine slept during this call; retrying once\n' "$what" >&2
    elif [ "$rc" -eq 124 ]; then
      printf 'fm-home-backup: %s: no response within %ss; retrying once\n' "$what" "$bound" >&2
    else
      printf 'fm-home-backup: %s: network error; retrying once\n' "$what" >&2
    fi
    sleep "$RETRY_PAUSE"
    attempt=2
  done
}

# A git transfer moves real data, so it is bounded by stalls (git's low-speed
# detector) and a generous wall ceiling rather than the short privacy-check
# bounds: a slow but flowing clone or push must not be cut off.
net_transfer() { # <what> <command...>
  local rc=0
  NET_TRANSFER=1
  net_call "$@" || rc=$?
  NET_TRANSFER=0
  return "$rc"
}

# --- resolution -------------------------------------------------------------

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)

# A firstmate repo root is identified by the libraries this command needs, not by
# its name or its position, so neither a same-named directory nor a relocation
# can satisfy it by accident.
looks_like_fm_root() {
  [ -f "$1/bin/fm-ff-lib.sh" ] && [ -f "$1/bin/fm-secondmate-registry-lib.sh" ]
}

CONFIG_DIR=${FM_HOME_BACKUP_CONFIG:-${XDG_CONFIG_HOME:-$HOME/.config}/fm-home-backup}
TARGET_FILE="$CONFIG_DIR/target"
HOME_FILE="$CONFIG_DIR/home"
ACK_FILE="$CONFIG_DIR/ack"
WORKDIR=${FM_HOME_BACKUP_WORKDIR:-${XDG_CACHE_HOME:-$HOME/.cache}/fm-home-backup}
REPO="$WORKDIR/repo"
LOCK="$WORKDIR/lock"

# First non-blank, non-comment line of a single-value config file.
config_value() {
  local file=$1 line
  [ -f "$file" ] && [ ! -L "$file" ] || return 1
  while IFS= read -r line || [ -n "$line" ]; do
    case $line in
      '' | '#'*) continue ;;
    esac
    printf '%s\n' "$line"
    return 0
  done < "$file"
  return 1
}

# --- operator configuration -------------------------------------------------

setup_hint() {
  cat >&2 <<EOF
Configure the private backup repo once, then re-run:
  gh repo create <owner>/<repo> --private
  mkdir -p '$CONFIG_DIR'
  printf '%s\n' '<owner>/<repo>' > '$TARGET_FILE'
EOF
}

if ! TARGET_SLUG=$(config_value "$TARGET_FILE"); then
  printf 'fm-home-backup: no backup target configured at %s\n' "$TARGET_FILE" >&2
  setup_hint
  exit 1
fi
# One positive check, so the refusal exists exactly once and the two halves of
# "is a slug" cannot drift apart: exactly one slash, and a non-empty owner and
# repo drawn from GitHub's name charset on either side of it.
slug_ok=0
case $TARGET_SLUG in
  */*/* | *[!A-Za-z0-9._/-]*) ;;
  [A-Za-z0-9._-]*/[A-Za-z0-9._-]*) slug_ok=1 ;;
esac
if [ "$slug_ok" -eq 0 ]; then
  printf 'fm-home-backup: %s must hold one GitHub owner/repo slug, got: %s\n' \
    "$TARGET_FILE" "$TARGET_SLUG" >&2
  setup_hint
  exit 1
fi

SIBLING_ROOT=$(cd "$SCRIPT_DIR/.." && pwd -P)

resolved_fm_home=
if [ -n "${FM_HOME:-}" ]; then
  resolved_fm_home=$FM_HOME
elif resolved_fm_home=$(config_value "$HOME_FILE"); then
  case $resolved_fm_home in
    /*) ;;
    *) die "$HOME_FILE must hold an absolute path, got: $resolved_fm_home" ;;
  esac
elif looks_like_fm_root "$SIBLING_ROOT"; then
  resolved_fm_home=$SIBLING_ROOT
else
  die "no firstmate home resolved. Set FM_HOME, or record the primary home once:
  mkdir -p '$CONFIG_DIR' && printf '%s\n' /absolute/path/to/firstmate > '$HOME_FILE'"
fi

[ -d "$resolved_fm_home" ] || die "firstmate home is not a directory: $resolved_fm_home"
FM_HOME=$(cd "$resolved_fm_home" && pwd -P)
export FM_HOME

if [ -n "${FM_ROOT_OVERRIDE:-}" ]; then
  FM_ROOT=$FM_ROOT_OVERRIDE
elif looks_like_fm_root "$SIBLING_ROOT"; then
  FM_ROOT=$SIBLING_ROOT
elif looks_like_fm_root "$FM_HOME"; then
  FM_ROOT=$FM_HOME
else
  die "no firstmate repo root supplying bin/fm-ff-lib.sh was found next to $SCRIPT_DIR or at $FM_HOME. Set FM_ROOT_OVERRIDE to a firstmate checkout."
fi
looks_like_fm_root "$FM_ROOT" \
  || die "FM_ROOT '$FM_ROOT' does not provide bin/fm-ff-lib.sh and bin/fm-secondmate-registry-lib.sh"
FM_ROOT=$(cd "$FM_ROOT" && pwd -P)
export FM_ROOT

# firstmate owns the secondmate registry format, the home-safety predicate, and
# the marker that separates a primary home from a secondmate home. Sourcing those
# libraries keeps this command from carrying a second copy of contracts it does
# not own, which would drift the first time only one copy was edited.
# shellcheck source=/dev/null
. "$FM_ROOT/bin/fm-ff-lib.sh"

PRIMARY_ID=main

# The capture allowlist. Both verbs need it: backup decides what to read from a
# home with it, and restore decides what a MANIFEST is allowed to describe with
# it, so it lives above the mode branch and has exactly one definition.
CAPTURED_TREES='data config'

lower() { printf '%s' "$1" | tr '[:upper:]' '[:lower:]'; }

# Membership test for the space-separated tree lists used by both verbs.
tree_listed() { # <name> <space-separated list>
  local candidate
  for candidate in $2; do
    [ "$1" != "$candidate" ] || return 0
  done
  return 1
}

# --- run cleanup ------------------------------------------------------------
#
# Armed before the first network call, so a run terminated during the privacy
# check is classified the same way as one terminated during the push.

LOCK_HELD=0
TMP=
# Set once restore has staged trees inside the destination. While a swap is in
# flight that scratch directory holds the only copy of the trees it has already
# moved aside, so cleanup must leave it for the operator instead of reaping it.
RESTORE_SCRATCH=
RESTORE_SWAPPING=0

# shellcheck disable=SC2317,SC2329 # Reached only through the traps below.
cleanup() {
  [ "$LOCK_HELD" -eq 0 ] || rm -rf -- "$LOCK"
  [ -z "$TMP" ] || rm -rf -- "$TMP"
  if [ -n "$RESTORE_SCRATCH" ] && [ "$RESTORE_SWAPPING" -eq 0 ]; then
    rm -rf -- "$RESTORE_SCRATCH"
  fi
}
trap cleanup EXIT
trap 'cleanup; exit 130' INT
# SIGTERM is how a supervisor such as the watcher's per-check timeout stops a
# run. Nothing is half-published by one (see IDEMPOTENCE), so it is a skipped
# run and exits 75 rather than reading as a failure.
# shellcheck disable=SC2154 # EX_TEMPFAIL is set above, in the network bounds.
trap 'printf "fm-home-backup: terminated before finishing; nothing is half-published, and the next run re-syncs from origin and retries\n" >&2; cleanup; exit $EX_TEMPFAIL' TERM

# --- target resolution and privacy verification -----------------------------

command -v gh > /dev/null 2>&1 \
  || die "gh is not on PATH; fm-home-backup resolves and privacy-checks the backup repo through gh"

# The fields are joined on a unit separator rather than a tab: bash collapses a
# run of IFS whitespace into one delimiter, so an empty visibility or an empty
# clone URL in a tab-separated payload would silently shift every later field into
# the wrong variable. A unit separator is not IFS whitespace, so an empty field
# stays an empty field and fails its own check instead of corrupting another.
# .isPrivate deliberately does not use jq's "//" default: "false // x" yields x,
# so a public repo would be rewritten into whatever default was supplied.
# The work dir is created before the first network call: run_bounded keeps its
# timeout markers there, inside the only directory this command writes to.
mkdir -p "$WORKDIR" || die "could not create work dir: $WORKDIR"

# A network failure here exits 75 inside net_call - still before any push, so the
# privacy refusal holds; only its classification differs from the refusals below.
gh_rc=0
net_call "could not reach GitHub to read $TARGET_SLUG, so target privacy could not be confirmed" \
  gh repo view "$TARGET_SLUG" \
  --json isPrivate,visibility,url,nameWithOwner,defaultBranchRef \
  --jq '[(.isPrivate | tostring), ((.visibility // "") | tostring), ((.url // "") | tostring), ((.nameWithOwner // "") | tostring), ((.defaultBranchRef.name // "") | tostring)] | join("\u001f")' \
  || gh_rc=$?
gh_out=$NET_OUT
if [ "$gh_rc" -ne 0 ]; then
  printf 'fm-home-backup: could not read %s through gh (exit %s):\n%s\n' \
    "$TARGET_SLUG" "$gh_rc" "$gh_out" >&2
  die "target privacy could not be confirmed, so nothing was pushed"
fi

IFS=$'\037' read -r TARGET_PRIVATE TARGET_VISIBILITY TARGET_URL TARGET_NAME TARGET_BRANCH \
  <<< "$gh_out" || true
[ -n "$TARGET_URL" ] || die "gh reported no clone URL for $TARGET_SLUG; refusing to guess one"
[ "$(lower "${TARGET_NAME:-}")" = "$(lower "$TARGET_SLUG")" ] \
  || die "gh resolved $TARGET_SLUG to '${TARGET_NAME:-}'; refusing to act on a repo other than the configured one"
[ -n "$TARGET_BRANCH" ] || TARGET_BRANCH=main

if [ "$MODE" = backup ]; then
  # Two independent assertions from the payload: a missing or null field can
  # never read as private, it can only fail to be "true"/"PRIVATE".
  if [ "$TARGET_PRIVATE" != true ] || [ "$TARGET_VISIBILITY" != PRIVATE ]; then
    die "$TARGET_SLUG is not private (isPrivate=${TARGET_PRIVATE:-unset}, visibility=${TARGET_VISIBILITY:-unset}); refusing to push firstmate home data to it.
Make it private with: gh repo edit '$TARGET_SLUG' --visibility private --accept-visibility-change-consequences"
  fi
fi

# --- run scratch and lock ---------------------------------------------------


# Identity that survives pid reuse: the pid plus the kernel's own start time for
# it. A recycled pid belonging to some unrelated process reports a different
# start time, so a dead owner is never mistaken for a live one.
proc_identity() {
  ps -o lstart= -p "$1" 2> /dev/null | sed 's/^[[:space:]]*//;s/[[:space:]]*$//'
}

LOCK_GRACE_SECONDS=10

# mkdir is the atomic step, but the owner record lands a moment after it. A lock
# with no usable owner record is therefore treated as HELD until it is older than
# the grace window, so that instant cannot be read as abandoned and hand the same
# clone to two runs - while a lock genuinely torn by a hard kill still self-heals
# once the window passes. An age this cannot measure counts as held: refusing a
# scheduled run is cheap, two concurrent runs on one clone is not.
lock_is_within_grace() {
  local created now
  created=$(stat -f '%m' "$LOCK" 2> /dev/null || stat -c '%Y' "$LOCK" 2> /dev/null) || return 0
  now=$(date +%s 2> /dev/null) || return 0
  case "$created$now" in
    '' | *[!0-9]*) return 0 ;;
  esac
  [ "$((now - created))" -lt "$LOCK_GRACE_SECONDS" ]
}

lock_owner_is_alive() {
  local pid='' ident='' current
  if [ -f "$LOCK/owner" ]; then
    IFS= read -r pid < "$LOCK/owner" || pid=
    ident=$(sed -n '2p' "$LOCK/owner" 2> /dev/null) || ident=
  fi
  case $pid in
    *[!0-9]*) pid= ;;
  esac
  if [ -z "$pid" ] || [ -z "$ident" ]; then
    lock_is_within_grace
    return
  fi
  current=$(proc_identity "$pid")
  [ -n "$current" ] || return 1
  [ "$current" = "$ident" ]
}

take_lock() { # <identity>
  mkdir "$LOCK" 2> /dev/null || return 1
  # Claimed before the record is written, so an interrupt in between still frees
  # the lock through cleanup rather than leaving one nobody can attribute.
  LOCK_HELD=1
  printf '%s\n%s\n' "$$" "$1" > "$LOCK/owner" \
    || die "could not record this run as the owner of $LOCK"
}

acquire_lock() {
  local ident
  ident=$(proc_identity $$)
  # An empty identity could never match a later check, which would make the lock
  # unbreakable for every future run, so it is refused rather than recorded.
  [ -n "$ident" ] \
    || die "could not read this run's own process start time, so its lock ownership would be unverifiable; refusing to take $LOCK"
  take_lock "$ident" && return 0
  lock_owner_is_alive && return 1
  rm -rf -- "$LOCK"
  take_lock "$ident"
}

if ! acquire_lock; then
  if [ "$MODE" = restore ]; then
    lock_holder=$(sed -n '1p' "$LOCK/owner" 2> /dev/null) || lock_holder=
    die "another run holds $LOCK (pid ${lock_holder:-unknown}); refusing to restore while it is active, because a recovery that wrote nothing must never look like one that succeeded. Re-run once that run finishes."
  fi
  printf 'fm-home-backup: another run holds %s; taking no action\n' "$LOCK"
  exit 0
fi

TMP=$(mktemp -d "$WORKDIR/run.XXXXXX") || die "could not create run scratch under $WORKDIR"
# Holding the lock means no other run is active, so any other run.* directory is
# debris from a run killed before its trap could fire. Sweeping it here is what
# keeps a hard kill from slowly filling the work dir.
for stale in "$WORKDIR"/run.*; do
  [ -d "$stale" ] && [ "$stale" != "$TMP" ] || continue
  rm -rf -- "$stale"
done
# Timeout markers are removed by the call that made them; one older than any
# bound was orphaned by a hard kill. A concurrent run's live marker is minutes
# younger than this, so it is never swept from under that run.
find "$WORKDIR" -maxdepth 1 -type f -name 'net.*' -mmin +60 -exec rm -f -- {} + 2> /dev/null || true

# --- backup clone -----------------------------------------------------------

git_repo() { git -c core.autocrlf=false -C "$REPO" "$@"; }

# A failed attempt can leave a partial clone behind, so each attempt - the retry
# included - starts from an empty destination.
# shellcheck disable=SC2329 # Invoked through net_call.
clone_attempt() {
  rm -rf -- "$REPO"
  git -c core.autocrlf=false clone --quiet -- "$TARGET_URL" "$REPO"
}

clone_fresh() {
  net_transfer "could not clone $TARGET_SLUG" clone_attempt \
    || die "could not clone $TARGET_SLUG from $TARGET_URL:
$NET_OUT"
}

sync_repo() {
  local current=
  if [ -d "$REPO/.git" ]; then
    current=$(git_repo remote get-url origin 2> /dev/null) || current=
    if [ "$current" != "$TARGET_URL" ]; then
      clone_fresh
    fi
  else
    clone_fresh
  fi
  net_transfer "could not fetch $TARGET_SLUG" git_repo fetch --quiet --prune origin \
    || die "could not fetch $TARGET_SLUG:
$NET_OUT"
  if git_repo rev-parse --verify --quiet "refs/remotes/origin/$TARGET_BRANCH" > /dev/null; then
    git_repo checkout --quiet -B "$TARGET_BRANCH" "refs/remotes/origin/$TARGET_BRANCH" \
      || die "could not check out $TARGET_BRANCH"
    git_repo reset --quiet --hard "refs/remotes/origin/$TARGET_BRANCH" \
      || die "could not reset to origin/$TARGET_BRANCH"
  else
    git_repo checkout --quiet -B "$TARGET_BRANCH" \
      || die "could not start branch $TARGET_BRANCH in an empty $TARGET_SLUG"
  fi
  git_repo clean --quiet -ffdx || die "could not clean the backup clone"
}

sync_repo

if [ "$MODE" = restore ]; then
  # --- restore ------------------------------------------------------------
  HOMEDIR="$REPO/$RESTORE_ID"
  MANIFEST="$HOMEDIR/MANIFEST"
  if [ ! -d "$HOMEDIR" ]; then
    available=$(find "$REPO" -mindepth 1 -maxdepth 1 -type d ! -name '.git' 2> /dev/null | sed 's|.*/||' | LC_ALL=C sort | tr '\n' ' ')
    die "no home '$RESTORE_ID' in $TARGET_SLUG. Available: ${available:-none}"
  fi
  [ -f "$MANIFEST" ] || die "$RESTORE_ID has no MANIFEST in $TARGET_SLUG; refusing to restore an unlabelled tree"

  RESTORE_SOURCE=
  TREES=()
  while IFS= read -r line || [ -n "$line" ]; do
    case $line in
      'source '*) RESTORE_SOURCE=${line#source } ;;
      'tree '*' present')
        tree=${line#tree }
        tree=${tree% present}
        tree_listed "$tree" "$CAPTURED_TREES" \
          || die "$RESTORE_ID/MANIFEST claims a captured tree this command never captures: '$tree'. Only $CAPTURED_TREES are ever written into a home."
        TREES+=("$tree")
        ;;
    esac
  done < "$MANIFEST"
  [ "${#TREES[@]}" -gt 0 ] || die "$RESTORE_ID/MANIFEST records no captured trees"

  # Everything below builds destination paths out of MANIFEST, so every entry is
  # checked before any of it is used: a mode that is not octal would reach chmod
  # as a flag, and a path that is absolute, carries a "." or ".." component, or
  # is not rooted in one of this manifest's own captured trees would reach
  # outside --into. Both are refusals naming the entry, never silent skips.
  while IFS=' ' read -r kind mode rel || [ -n "$kind" ]; do
    case $kind in
      d | f) ;;
      *) continue ;;
    esac
    case $mode in
      '' | *[!0-7]*) die "$RESTORE_ID/MANIFEST entry '$kind $mode $rel' does not record an octal mode" ;;
    esac
    case $rel in
      '' | /*) die "$RESTORE_ID/MANIFEST entry '$kind $mode $rel' is not a relative path" ;;
    esac
    case "/$rel/" in
      */../* | */./*) die "$RESTORE_ID/MANIFEST entry '$kind $mode $rel' walks out of the destination" ;;
    esac
    tree_listed "${rel%%/*}" "${TREES[*]}" \
      || die "$RESTORE_ID/MANIFEST entry '$kind $mode $rel' is not inside a captured tree of this home"
  done < "$MANIFEST"

  # A home the last backup could not reach keeps its previous capture rather than
  # being wiped, so the tree about to be placed can be older than the rest of the
  # repo and nothing in MANIFEST records when it was taken. SNAPSHOT is the only
  # place that knows, so restore reads it and says so rather than making the
  # operator think to look.
  STALE_HOME=
  STALE_REASON=
  if [ -f "$REPO/SNAPSHOT" ]; then
    while IFS=' ' read -r kind sid shome sreason || [ -n "$kind" ]; do
      [ "$kind" = uncaptured-home ] && [ "$sid" = "$RESTORE_ID" ] || continue
      STALE_HOME=$shome
      STALE_REASON=$sreason
      break
    done < "$REPO/SNAPSHOT"
  fi

  stale_warning() {
    printf '  !! WARNING: home %s was NOT captured by the most recent backup.\n' "$RESTORE_ID"
    printf '  !! SNAPSHOT records it as uncaptured-home: %s (%s)\n' \
      "${STALE_HOME:-unrecorded path}" "${STALE_REASON:-no reason recorded}"
    printf '  !! These files are from the last SUCCESSFUL capture and are of\n'
    printf '  !! unknown age - nothing this tool writes carries a timestamp.\n'
    printf '  !! Check that home before trusting what lands here.\n'
  }

  printf 'restore plan for home %s from %s (%s)\n' "$RESTORE_ID" "$TARGET_SLUG" "$TARGET_VISIBILITY"
  printf '  originally captured from: %s\n' "${RESTORE_SOURCE:-unrecorded}"
  printf '  destination:              %s\n' "$RESTORE_INTO"
  printf '  trees:                    %s\n' "${TREES[*]}"
  if [ -n "$STALE_HOME" ] || [ -n "$STALE_REASON" ]; then
    stale_warning
  fi
  dirs=0
  files=0
  while IFS=' ' read -r kind mode rel || [ -n "$kind" ]; do
    case $kind in
      d)
        printf '  mkdir  %s  %s/%s\n' "$mode" "$RESTORE_INTO" "$rel"
        dirs=$((dirs + 1))
        ;;
      f)
        printf '  place  %s  %s/%s\n' "$mode" "$RESTORE_INTO" "$rel"
        files=$((files + 1))
        ;;
    esac
  done < "$MANIFEST"
  printf '  total: %s directories, %s files\n' "$dirs" "$files"

  if [ "$APPLY" -eq 0 ]; then
    printf 'nothing was written. Re-run with --apply to place these files.\n'
    exit 0
  fi

  [ -d "$RESTORE_INTO" ] \
    || die "--into '$RESTORE_INTO' does not exist. Create it deliberately first: mkdir -p '$RESTORE_INTO'"
  RESTORE_INTO=$(cd "$RESTORE_INTO" && pwd -P)
  [ "$RESTORE_INTO" != / ] || die "refusing to restore into the filesystem root"
  case "$RESTORE_INTO/" in
    "$WORKDIR"/*) die "refusing to restore into the backup work dir: $RESTORE_INTO" ;;
  esac

  if [ "$FORCE" -eq 0 ]; then
    for tree in "${TREES[@]}"; do
      if [ -d "$RESTORE_INTO/$tree" ] && [ -n "$(ls -A -- "$RESTORE_INTO/$tree" 2> /dev/null)" ]; then
        die "$RESTORE_INTO/$tree already has content. Re-run with --force to replace it."
      fi
    done
  fi

  # Staging inside the destination is what makes both halves of the swap a
  # same-filesystem rename even when --into is on another disk, where a copy out
  # of the work dir would instead be interruptible half way through a tree.
  restore_scratch="$RESTORE_INTO/.fm-home-backup-restore"
  if [ -e "$restore_scratch" ] || [ -L "$restore_scratch" ]; then
    die "$restore_scratch already exists, which is where an interrupted restore leaves the trees it had already moved aside. Inspect and remove it deliberately, then re-run."
  fi
  RESTORE_SCRATCH=$restore_scratch
  STAGE="$RESTORE_SCRATCH/stage"
  PREVIOUS="$RESTORE_SCRATCH/previous"
  mkdir -p "$STAGE" "$PREVIOUS" || die "could not create the restore staging area $RESTORE_SCRATCH"
  for tree in "${TREES[@]}"; do
    mkdir -p "$STAGE/$tree" || die "could not stage $tree"
  done
  while IFS=' ' read -r kind mode rel || [ -n "$kind" ]; do
    case $kind in
      d) mkdir -p "$STAGE/$rel" ;;
      f)
        [ -f "$HOMEDIR/$rel" ] || die "$RESTORE_ID/MANIFEST lists $rel but the backup has no such file"
        mkdir -p "$(dirname "$STAGE/$rel")"
        cp -- "$HOMEDIR/$rel" "$STAGE/$rel" || die "could not stage $rel"
        chmod "$mode" "$STAGE/$rel" || die "could not set mode $mode on staged $rel"
        ;;
    esac
  done < "$MANIFEST"
  # Directories are chmod'ed deepest first. A tree root now carries its own mode,
  # so applying parents first could drop the traversal bit on a directory whose
  # children still need chmod'ing.
  DIR_MODES="$TMP/restore-dir-modes"
  : > "$DIR_MODES"
  while IFS=' ' read -r kind mode rel || [ -n "$kind" ]; do
    [ "$kind" = d ] || continue
    printf '%s\t%s\n' "$rel" "$mode" >> "$DIR_MODES"
  done < "$MANIFEST"
  LC_ALL=C sort -r "$DIR_MODES" > "$DIR_MODES.deepest-first"
  while IFS=$'\t' read -r rel mode || [ -n "$rel" ]; do
    [ -n "$rel" ] || continue
    chmod "$mode" "$STAGE/$rel" || die "could not set mode $mode on staged directory $rel"
  done < "$DIR_MODES.deepest-first"

  # Swap whole trees rather than merging into a live one, and move the existing
  # tree aside before the staged one lands rather than deleting it first, so no
  # step can leave a destination tree half-written or destroyed. From here until
  # the restore verifies, that aside copy is the only one, so cleanup leaves the
  # scratch directory alone.
  RESTORE_SWAPPING=1
  for tree in "${TREES[@]}"; do
    [ -d "$STAGE/$tree" ] || die "staged restore is missing $tree"
    if [ -e "$RESTORE_INTO/$tree" ] || [ -L "$RESTORE_INTO/$tree" ]; then
      mv -- "$RESTORE_INTO/$tree" "$PREVIOUS/$tree" \
        || die "could not move the existing $tree aside in $RESTORE_INTO"
    fi
    mv -- "$STAGE/$tree" "$RESTORE_INTO/$tree" || die "could not place $tree into $RESTORE_INTO"
  done

  while IFS=' ' read -r kind mode rel || [ -n "$kind" ]; do
    case $kind in
      f) [ -f "$RESTORE_INTO/$rel" ] || die "restore finished but $RESTORE_INTO/$rel is missing" ;;
      d) [ -d "$RESTORE_INTO/$rel" ] || die "restore finished but directory $RESTORE_INTO/$rel is missing" ;;
      *) continue ;;
    esac
    have=$(stat -f '%Lp' "$RESTORE_INTO/$rel" 2> /dev/null || stat -c '%a' "$RESTORE_INTO/$rel" 2> /dev/null || printf '?')
    [ "$have" = "$mode" ] || die "restore finished but $RESTORE_INTO/$rel has mode $have, expected $mode"
  done < "$MANIFEST"

  rm -rf -- "$RESTORE_SCRATCH" || die "restored $RESTORE_INTO but could not remove $RESTORE_SCRATCH"
  RESTORE_SCRATCH=
  RESTORE_SWAPPING=0

  printf 'restored %s files into %s (state/ and projects/ untouched)\n' "$files" "$RESTORE_INTO"
  if [ -n "$STALE_HOME" ] || [ -n "$STALE_REASON" ]; then
    stale_warning >&2
  fi
  exit 0
fi

# --- backup: home discovery -------------------------------------------------

[ -f "$FM_HOME/AGENTS.md" ] || die "FM_HOME '$FM_HOME' is not a firstmate home (no AGENTS.md)"
[ -d "$FM_HOME/bin" ] || die "FM_HOME '$FM_HOME' is not a firstmate home (no bin/)"
if [ -e "$FM_HOME/$SUB_HOME_MARKER" ] || [ -L "$FM_HOME/$SUB_HOME_MARKER" ]; then
  die "FM_HOME '$FM_HOME' is a secondmate home. Run fm-home-backup from the primary home, which owns the registry that lists every home."
fi

HOMES="$TMP/homes"
UNSUPPORTED="$TMP/unsupported"
: > "$HOMES"
: > "$UNSUPPORTED"
printf '%s\t%s\n' "$PRIMARY_ID" "$FM_HOME" >> "$HOMES"

REGISTRY="$FM_HOME/data/secondmates.md"
if [ -L "$REGISTRY" ]; then
  die "data/secondmates.md is a symlink; refusing to read the home registry through one"
elif [ -f "$REGISTRY" ]; then
  secondmate_registry_validate_bindings "$REGISTRY" secondmate_registry_path_key \
    || die "secondmate registry is unusable: $SECONDMATE_REGISTRY_ERROR"
  grep '^- ' "$REGISTRY" > "$TMP/records" 2> /dev/null || : > "$TMP/records"
  while IFS= read -r line || [ -n "$line" ]; do
    [ -n "$line" ] || continue
    secondmate_registry_parse_line "$line" \
      || die "malformed secondmate registry entry: $line"
    id=$SECONDMATE_REGISTRY_ID
    [ "$id" != "$PRIMARY_ID" ] \
      || die "a secondmate is registered as '$PRIMARY_ID', which collides with the primary home's directory in the backup repo. Rename it in data/secondmates.md."
    if [ "$SECONDMATE_REGISTRY_REMOTE" -eq 1 ]; then
      printf 'unsupported-remote\t%s\t%s\t%s\n' \
        "$id" "$SECONDMATE_REGISTRY_HOST" "$SECONDMATE_REGISTRY_HOME" >> "$UNSUPPORTED"
      continue
    fi
    # A registered home that is not a usable secondmate home is recorded and
    # skipped rather than fatal. Refusing the whole run here would mean one
    # renamed or deleted directory silently stops the primary home's memory
    # being backed up at all, which is the outcome this command exists to
    # prevent; the skip is loud, in SNAPSHOT and on stderr, and the run exits 3.
    # This reaches only homes whose parent path still resolves. A home on an
    # unmounted volume has no resolvable parent either, so the shared binding
    # validator above has already refused the whole run before this point - see
    # HOME DISCOVERY in the header for that two-tier boundary.
    if ! validate_secondmate_home "$id" "$SECONDMATE_REGISTRY_HOME"; then
      printf 'uncaptured-home\t%s\t%s\t%s\n' \
        "$id" "$SECONDMATE_REGISTRY_HOME" "$VALIDATION_ERROR" >> "$UNSUPPORTED"
      continue
    fi
    printf '%s\t%s\n' "$id" "$VALIDATED_HOME" >> "$HOMES"
  done < "$TMP/records"
fi

# --- backup: capture --------------------------------------------------------

# High-precision name shapes only. A broad "anything mentioning secret" rule
# would refuse ordinary firstmate research notes, which trains an operator to
# route around the guard - the failure mode this refusal exists to prevent.
credential_shaped() {
  case ${1##*/} in
    .env | .env.* | *.env | .envrc | .envrc.*) return 0 ;;
    .netrc | .npmrc | .pypirc | .git-credentials | .htpasswd) return 0 ;;
    *.pem | *.p8 | *.p12 | *.pfx | *.jks | *.keystore | *.key | *.asc | *.gpg) return 0 ;;
    id_rsa* | id_dsa* | id_ecdsa* | id_ed25519* | *_rsa | *_ed25519) return 0 ;;
    credentials | credentials.* | *.credentials) return 0 ;;
  esac
  return 1
}

acked() {
  [ -f "$ACK_FILE" ] && [ ! -L "$ACK_FILE" ] || return 1
  grep -Fxq -- "$1" "$ACK_FILE"
}

file_mode() {
  stat -f '%Lp' "$1" 2> /dev/null || stat -c '%a' "$1" 2> /dev/null
}

STAGED_PATHS="$TMP/staged-paths"
: > "$STAGED_PATHS"

# A tab or a newline inside a captured path would silently corrupt MANIFEST's
# line format, so both are refused rather than escaped.
TAB=$(printf '\t')
NL='
'

capture_home() { # <id> <home>
  local id=$1 home=$2 dest="$REPO/$1" manifest="$TMP/manifest.$1"
  local tree src entry rel mode

  rm -rf -- "$dest"
  mkdir -p "$dest"
  {
    printf '# fm-home-backup manifest v1\n'
    printf 'home %s\n' "$id"
    printf 'source %s\n' "$home"
  } > "$manifest"

  for tree in $CAPTURED_TREES; do
    src="$home/$tree"
    if [ -L "$src" ]; then
      die "$id: $tree is a symlink at $src; refusing to follow it out of the home"
    elif [ ! -e "$src" ]; then
      printf 'tree %s absent\n' "$tree" >> "$manifest"
      continue
    elif [ ! -d "$src" ]; then
      die "$id: $src is not a directory"
    fi
    printf 'tree %s present\n' "$tree" >> "$manifest"
    # The tree root carries a mode like every other directory. Without its own
    # entry a 0700 config/ would come back at the restoring process's umask,
    # widening the directory that holds the 0600 files inside it.
    mode=$(file_mode "$src") || die "$id: could not read the mode of $src"
    printf 'd %s %s\n' "$mode" "$tree" >> "$manifest.body"

    find "$src" -mindepth 1 -print0 > "$TMP/entries" 2> /dev/null \
      || die "$id: could not enumerate $src"
    while IFS= read -r -d '' entry; do
      rel=${entry#"$home/"}
      case $rel in
        *"$TAB"* | *"$NL"*) die "$id: refusing a path containing a tab or newline: $entry" ;;
      esac
      if [ -L "$entry" ]; then
        die "$id: refusing symlink $entry. Replace it with a real file or move it out of $tree/."
      elif [ -d "$entry" ]; then
        mkdir -p "$dest/$rel" || die "$id: could not create $dest/$rel"
        mode=$(file_mode "$entry") || die "$id: could not read the mode of $entry"
        printf 'd %s %s\n' "$mode" "$rel" >> "$manifest.body"
      elif [ -f "$entry" ]; then
        if credential_shaped "$entry" && ! acked "$id/$rel"; then
          die "$id: $entry is credential-shaped and would be copied into the backup repo.
Move it out of $tree/, or acknowledge it deliberately:
  mkdir -p '$CONFIG_DIR' && printf '%s\n' '$id/$rel' >> '$ACK_FILE'"
        fi
        mode=$(file_mode "$entry") || die "$id: could not read the mode of $entry"
        mkdir -p "$(dirname "$dest/$rel")"
        cp -- "$entry" "$dest/$rel" || die "$id: could not copy $entry"
        chmod "$mode" "$dest/$rel" || die "$id: could not set mode $mode on $dest/$rel"
        printf 'f %s %s\n' "$mode" "$rel" >> "$manifest.body"
        printf '%s/%s\n' "$id" "$rel" >> "$STAGED_PATHS"
      else
        die "$id: $entry is neither a regular file nor a directory; refusing to guess how to store it"
      fi
    done < "$TMP/entries"
  done

  if [ -f "$manifest.body" ]; then
    LC_ALL=C sort "$manifest.body" >> "$manifest"
    rm -f -- "$manifest.body"
  fi
  cp -- "$manifest" "$dest/MANIFEST" || die "$id: could not write MANIFEST"
  printf '%s/MANIFEST\n' "$id" >> "$STAGED_PATHS"
}

CAPTURED_IDS=
while IFS=$'\t' read -r id home || [ -n "$id" ]; do
  [ -n "$id" ] || continue
  capture_home "$id" "$home"
  CAPTURED_IDS="$CAPTURED_IDS $id"
done < "$HOMES"

# --- backup: fleet snapshot and README --------------------------------------
#
# Both files are content-only. No timestamp appears anywhere this tool writes,
# which is what makes an unchanged fleet a genuine no-op instead of a daily
# commit that only records that the tool ran.

{
  printf '# fm-home-backup snapshot v1\n'
  while IFS=$'\t' read -r id home || [ -n "$id" ]; do
    [ -n "$id" ] || continue
    printf 'home %s %s\n' "$id" "$home"
  done < "$HOMES"
  while IFS=$'\t' read -r kind id detail reason || [ -n "$kind" ]; do
    [ -n "$kind" ] || continue
    printf '%s %s %s %s\n' "$kind" "$id" "$detail" "$reason"
  done < "$UNSUPPORTED"
} > "$REPO/SNAPSHOT"
printf 'SNAPSHOT\n' >> "$STAGED_PATHS"

cat > "$REPO/README.md" <<'READMEEOF'
# firstmate home backup

Generated by `fm-home-backup.sh`. Every file here is rewritten on each run, so
edits to this README, to `SNAPSHOT`, or to any `MANIFEST` are overwritten.

Each top-level directory is one firstmate home, named by its home id: `main` is
the primary home, every other directory is a registered secondmate. A home holds
only its `data/` and `config/` trees plus a `MANIFEST` recording every captured
directory and file with its mode, because git stores neither empty directories
nor exact permissions.

`SNAPSHOT` lists the homes this fleet had at the last capture, and names any
registered home that was NOT captured. Read it before assuming coverage.

Deliberately absent, and not recoverable from here: `state/`, which is runtime
scaffolding that is safer to rebuild than to restore stale, and `projects/`,
whose clones come back from their own remotes.

To restore one home:

    fm-home-backup.sh restore --home main --into /path/to/home            # plan
    fm-home-backup.sh restore --home main --into /path/to/home --apply    # write

The plan form writes nothing. `--apply` refuses to replace a populated `data/`
or `config/` unless `--force` is also given, and never touches `state/` or
`projects/` under the destination.
READMEEOF
printf 'README.md\n' >> "$STAGED_PATHS"

# --- backup: stage, verify, publish -----------------------------------------

git_repo add -A || die "could not stage the snapshot"

# The backup repo is not this tool's; a .gitignore in it would make git skip
# staged files and let this run report success while storing less than it
# copied. Refuse instead.
ignore_rc=0
ignored=$(git_repo check-ignore --stdin < "$STAGED_PATHS" 2>&1) || ignore_rc=$?
case $ignore_rc in
  0)
    die "$TARGET_SLUG has a .gitignore that excludes captured files, so they would not be stored:
$ignored"
    ;;
  1) ;;
  *) die "could not check $TARGET_SLUG's ignore rules: $ignored" ;;
esac

# Second, independent signal: everything intended for a home is actually tracked.
for id in $CAPTURED_IDS; do
  want=$(awk -v prefix="$id/" 'index($0, prefix) == 1 { n++ } END { print n + 0 }' "$STAGED_PATHS")
  have=$(git_repo ls-files -- "$id/" | wc -l | tr -d ' ')
  [ "$want" = "$have" ] \
    || die "$id: staged $want files but git tracks $have; refusing to publish an incomplete snapshot"
done

if [ -z "$(git_repo status --porcelain)" ]; then
  if [ "$DRY_RUN" -eq 1 ]; then
    printf 'fm-home-backup: no changes (dry run); homes:%s\n' "$CAPTURED_IDS"
  else
    printf 'fm-home-backup: no changes; homes:%s\n' "$CAPTURED_IDS"
  fi
else
  if [ "$DRY_RUN" -eq 1 ]; then
    printf 'fm-home-backup: would commit and push to %s:\n' "$TARGET_SLUG"
    git_repo status --short
    git_repo reset --quiet --hard HEAD 2> /dev/null || git_repo rm --quiet -r --cached . 2> /dev/null || true
    git_repo clean --quiet -ffdx || true
  else
    git_repo -c user.name=fm-home-backup -c user.email=fm-home-backup@localhost \
      commit --quiet -m "backup:$CAPTURED_IDS" \
      || die "could not commit the snapshot"
    net_transfer "could not push to $TARGET_SLUG" \
      git_repo push --quiet origin "HEAD:refs/heads/$TARGET_BRANCH" \
      || die "could not push to $TARGET_SLUG. The next run re-syncs from origin and retries:
$NET_OUT"
    printf 'fm-home-backup: pushed to %s (%s); homes:%s\n' \
      "$TARGET_SLUG" "$TARGET_BRANCH" "$CAPTURED_IDS"
  fi
fi

if [ -s "$UNSUPPORTED" ]; then
  while IFS=$'\t' read -r kind id detail reason || [ -n "$kind" ]; do
    [ -n "$kind" ] || continue
    case $kind in
      unsupported-remote)
        printf 'fm-home-backup: NOT captured - secondmate %s is remote (%s:%s); this version has no remote reader. Back that home up from its own host, or extend fm-home-backup.sh with a remote reader.\n' \
          "$id" "$detail" "$reason" >&2
        ;;
      uncaptured-home)
        printf 'fm-home-backup: NOT captured - secondmate %s has an unusable home %s: %s. Every other home was captured and pushed. Fix that home, or unregister it in %s.\n' \
          "$id" "$detail" "$reason" "$REGISTRY" >&2
        ;;
    esac
  done < "$UNSUPPORTED"
  exit 3
fi
exit 0
