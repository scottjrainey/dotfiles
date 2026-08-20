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
# The primary home is FM_HOME. Secondmates are read from that home's
# data/secondmates.md through firstmate's own registry parser and binding
# validator (bin/fm-secondmate-registry-lib.sh via bin/fm-ff-lib.sh), so adding a
# secondmate later needs no edit here and a malformed or overlapping registry is
# refused instead of half-read. A remote secondmate record (host:) is NOT
# supported by this version: it is named in SNAPSHOT as unsupported-remote, every
# local home is still captured and pushed, and the run exits 3. It is never
# silently skipped.
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
# pushing. Restore deliberately does NOT gate on privacy: it only reads, and
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
# end. A second concurrent invocation takes no action and exits 0 - a scheduled
# overlap is not a failure. The lock records its owner's pid and start time and is
# broken automatically when that process is gone, so a killed run cannot wedge
# every future backup.
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
#
# ENVIRONMENT
#   FM_HOME                  primary firstmate home (overrides <config-dir>/home)
#   FM_ROOT_OVERRIDE         firstmate repo root supplying bin/fm-ff-lib.sh
#   FM_HOME_BACKUP_CONFIG    operator config dir
#   FM_HOME_BACKUP_WORKDIR   work dir holding the backup clone and the lock
#
# EXIT STATUS
#   0  captured and pushed, clean no-op, or a plan-only restore
#   1  refusal or failure; nothing was pushed
#   2  invalid use
#   3  every local home was captured and pushed, but at least one registered
#      home is not supported by this version and was not captured
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
case $TARGET_SLUG in
  */*/* | */ | /* | *[!A-Za-z0-9._/-]*)
    printf 'fm-home-backup: %s must hold one GitHub owner/repo slug, got: %s\n' \
      "$TARGET_FILE" "$TARGET_SLUG" >&2
    setup_hint
    exit 1
    ;;
  */*) ;;
  *)
    printf 'fm-home-backup: %s must hold one GitHub owner/repo slug, got: %s\n' \
      "$TARGET_FILE" "$TARGET_SLUG" >&2
    setup_hint
    exit 1
    ;;
esac

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

lower() { printf '%s' "$1" | tr '[:upper:]' '[:lower:]'; }

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
gh_rc=0
gh_out=$(gh repo view "$TARGET_SLUG" \
  --json isPrivate,visibility,url,nameWithOwner,defaultBranchRef \
  --jq '[(.isPrivate | tostring), ((.visibility // "") | tostring), ((.url // "") | tostring), ((.nameWithOwner // "") | tostring), ((.defaultBranchRef.name // "") | tostring)] | join("\u001f")' \
  2>&1) || gh_rc=$?
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

mkdir -p "$WORKDIR" || die "could not create work dir: $WORKDIR"
LOCK_HELD=0
TMP=

# shellcheck disable=SC2317,SC2329 # Reached only through the traps below.
cleanup() {
  [ "$LOCK_HELD" -eq 0 ] || rm -rf -- "$LOCK"
  [ -z "$TMP" ] || rm -rf -- "$TMP"
}
trap cleanup EXIT
trap 'cleanup; exit 130' INT
trap 'cleanup; exit 143' TERM

# Identity that survives pid reuse: the pid plus the kernel's own start time for
# it. A recycled pid belonging to some unrelated process reports a different
# start time, so a dead owner is never mistaken for a live one.
proc_identity() {
  ps -o lstart= -p "$1" 2> /dev/null | sed 's/^[[:space:]]*//;s/[[:space:]]*$//'
}

lock_owner_is_alive() {
  local pid ident current
  [ -f "$LOCK/owner" ] || return 1
  IFS= read -r pid < "$LOCK/owner" || return 1
  IFS= read -r ident < <(sed -n '2p' "$LOCK/owner") || ident=
  case $pid in
    '' | *[!0-9]*) return 1 ;;
  esac
  current=$(proc_identity "$pid")
  [ -n "$current" ] || return 1
  [ "$current" = "$ident" ]
}

acquire_lock() {
  if mkdir "$LOCK" 2> /dev/null; then
    printf '%s\n%s\n' "$$" "$(proc_identity $$)" > "$LOCK/owner"
    LOCK_HELD=1
    return 0
  fi
  if lock_owner_is_alive; then
    return 1
  fi
  rm -rf -- "$LOCK"
  if mkdir "$LOCK" 2> /dev/null; then
    printf '%s\n%s\n' "$$" "$(proc_identity $$)" > "$LOCK/owner"
    LOCK_HELD=1
    return 0
  fi
  return 1
}

if ! acquire_lock; then
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

# --- backup clone -----------------------------------------------------------

git_repo() { git -c core.autocrlf=false -C "$REPO" "$@"; }

clone_fresh() {
  rm -rf -- "$REPO"
  git -c core.autocrlf=false clone --quiet -- "$TARGET_URL" "$REPO" \
    || die "could not clone $TARGET_SLUG from $TARGET_URL"
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
  git_repo fetch --quiet --prune origin || die "could not fetch $TARGET_SLUG"
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
  TREES=
  while IFS= read -r line || [ -n "$line" ]; do
    case $line in
      'source '*) RESTORE_SOURCE=${line#source } ;;
      'tree '*' present') TREES="$TREES ${line#tree }" ;;
    esac
  done < "$MANIFEST"
  TREES=$(printf '%s' "$TREES" | sed 's/ present//g')
  [ -n "$TREES" ] || die "$RESTORE_ID/MANIFEST records no captured trees"

  printf 'restore plan for home %s from %s (%s)\n' "$RESTORE_ID" "$TARGET_SLUG" "$TARGET_VISIBILITY"
  printf '  originally captured from: %s\n' "${RESTORE_SOURCE:-unrecorded}"
  printf '  destination:              %s\n' "$RESTORE_INTO"
  printf '  trees:                   %s\n' "$TREES"
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
    for tree in $TREES; do
      if [ -d "$RESTORE_INTO/$tree" ] && [ -n "$(ls -A -- "$RESTORE_INTO/$tree" 2> /dev/null)" ]; then
        die "$RESTORE_INTO/$tree already has content. Re-run with --force to replace it."
      fi
    done
  fi

  STAGE="$TMP/restore"
  mkdir -p "$STAGE"
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
  while IFS=' ' read -r kind mode rel || [ -n "$kind" ]; do
    [ "$kind" = d ] || continue
    chmod "$mode" "$STAGE/$rel" || die "could not set mode $mode on staged directory $rel"
  done < "$MANIFEST"

  # Swap whole trees rather than merging into a live one, so an interrupted
  # apply leaves either the previous tree or the restored tree, never a blend.
  for tree in $TREES; do
    [ -d "$STAGE/$tree" ] || die "staged restore is missing $tree"
    rm -rf -- "${RESTORE_INTO:?}/$tree"
    mv -- "$STAGE/$tree" "$RESTORE_INTO/$tree" || die "could not place $tree into $RESTORE_INTO"
  done

  while IFS=' ' read -r kind mode rel || [ -n "$kind" ]; do
    [ "$kind" = f ] || continue
    [ -f "$RESTORE_INTO/$rel" ] || die "restore finished but $RESTORE_INTO/$rel is missing"
    have=$(stat -f '%Lp' "$RESTORE_INTO/$rel" 2> /dev/null || stat -c '%a' "$RESTORE_INTO/$rel" 2> /dev/null || printf '?')
    [ "$have" = "$mode" ] || die "restore finished but $RESTORE_INTO/$rel has mode $have, expected $mode"
  done < "$MANIFEST"

  printf 'restored %s files into %s (state/ and projects/ untouched)\n' "$files" "$RESTORE_INTO"
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
      printf '%s\t%s\t%s\n' "$id" "$SECONDMATE_REGISTRY_HOST" "$SECONDMATE_REGISTRY_HOME" \
        >> "$UNSUPPORTED"
      continue
    fi
    validate_secondmate_home "$id" "$SECONDMATE_REGISTRY_HOME" \
      || die "secondmate $id has an unusable home '$SECONDMATE_REGISTRY_HOME': $VALIDATION_ERROR"
    printf '%s\t%s\n' "$id" "$VALIDATED_HOME" >> "$HOMES"
  done < "$TMP/records"
fi

# --- backup: capture --------------------------------------------------------

CAPTURED_TREES='data config'

# High-precision name shapes only. A broad "anything mentioning secret" rule
# would refuse ordinary firstmate research notes, which trains an operator to
# route around the guard - the failure mode this refusal exists to prevent.
credential_shaped() {
  case ${1##*/} in
    .env | .env.* | *.env) return 0 ;;
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
  while IFS=$'\t' read -r id host home || [ -n "$id" ]; do
    [ -n "$id" ] || continue
    printf 'unsupported-remote %s %s %s\n' "$id" "$host" "$home"
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
    git_repo push --quiet origin "HEAD:refs/heads/$TARGET_BRANCH" \
      || die "could not push to $TARGET_SLUG. The next run re-syncs from origin and retries."
    printf 'fm-home-backup: pushed to %s (%s); homes:%s\n' \
      "$TARGET_SLUG" "$TARGET_BRANCH" "$CAPTURED_IDS"
  fi
fi

if [ -s "$UNSUPPORTED" ]; then
  while IFS=$'\t' read -r id host home || [ -n "$id" ]; do
    [ -n "$id" ] || continue
    printf 'fm-home-backup: NOT captured - secondmate %s is remote (%s:%s); this version has no remote reader\n' \
      "$id" "$host" "$home" >&2
  done < "$UNSUPPORTED"
  printf 'fm-home-backup: back that home up from its own host, or extend fm-home-backup.sh with a remote reader\n' >&2
  exit 3
fi
exit 0
