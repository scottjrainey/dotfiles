#!/usr/bin/env bash
# Behavior tests for fm-home-backup.sh.
#
# Every case drives the real executable against a real local git remote and a
# fake `gh` on PATH, so the privacy gate, the clone/commit/push path, and the
# refusals are exercised as an operator would hit them. Nothing here reads the
# command's source.
set -u

# shellcheck source=tests/lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

BACKUP="$FM_BIN_DIR/fm-home-backup.sh"
[ -x "$BACKUP" ] || fail "fm-home-backup.sh is missing or not executable at $BACKUP"

# fm-home-backup deliberately sources firstmate's own registry parser and
# home-safety predicate rather than carrying second copies of them, so the
# fixtures need a real firstmate checkout to copy those two libraries from.
FIRSTMATE_SRC=${FM_HOME_BACKUP_TEST_FM_ROOT:-$HOME/repos/firstmate}
if [ ! -f "$FIRSTMATE_SRC/bin/fm-ff-lib.sh" ]; then
  fail "no firstmate checkout at $FIRSTMATE_SRC. Point the suite at one:
  FM_HOME_BACKUP_TEST_FM_ROOT=/path/to/firstmate $0"
fi

TMP_ROOT=$(fm_test_tmproot fm-home-backup) || fail "could not create a temp root"
fm_git_identity

# --- fixtures ---------------------------------------------------------------

stat_line() {
  stat -f '%N %p %m %z' "$1" 2> /dev/null || stat -c '%n %f %Y %s' "$1" 2> /dev/null
}

# Name, mode, mtime and size of every entry under a home. Reading a file changes
# only its atime, so an unchanged fingerprint proves the run created, deleted,
# modified and touched nothing.
home_fingerprint() {
  local d=$1 f
  (
    cd "$d" || exit 1
    find . -print | LC_ALL=C sort | while IFS= read -r f; do stat_line "$f"; done
  )
}

make_home() { # <dir> [secondmate-id]
  local dir=$1 id=${2:-}
  mkdir -p "$dir/data" "$dir/config" "$dir/state" "$dir/projects" "$dir/bin"
  printf '# home\n' > "$dir/AGENTS.md"
  printf 'runtime scaffolding\n' > "$dir/state/live.json"
  mkdir -p "$dir/projects/someclone"
  printf 'a project clone\n' > "$dir/projects/someclone/README.md"
  printf 'a private thing not on the allowlist\n' > "$dir/.env"
  [ -z "$id" ] || printf '%s\n' "$id" > "$dir/.fm-secondmate-home"
}

# One fully isolated case: a firstmate root supplying the sourced libraries, a
# primary home, an operator config dir, a work dir, a bare remote, and a gh stub.
# Called as `dir=$(new_case)`, which forks a subshell, so the case name cannot
# come from a counter in this shell - mktemp is what makes each case distinct.
new_case() { # echoes the case dir
  local dir
  dir=$(mktemp -d "$TMP_ROOT/case.XXXXXX") || return 1
  mkdir -p "$dir/fmroot/bin" "$dir/cfg" "$dir/work"
  cp "$FIRSTMATE_SRC/bin/fm-ff-lib.sh" "$FIRSTMATE_SRC/bin/fm-secondmate-registry-lib.sh" \
    "$dir/fmroot/bin/"
  make_home "$dir/homes/main"
  printf 'captain backlog\n' > "$dir/homes/main/data/backlog.md"
  printf 'tmux\n' > "$dir/homes/main/config/backend"
  git init --bare -q --initial-branch=main "$dir/bare.git"
  printf 'owner/backup\n' > "$dir/cfg/target"
  local fakebin
  fakebin=$(fm_fakebin "$dir")
  cat > "$fakebin/gh" <<'GHEOF'
#!/usr/bin/env bash
if [ "${GH_STUB_FAIL:-0}" = 1 ]; then
  printf 'GraphQL: Could not resolve to a Repository with the name.\n' >&2
  exit 1
fi
printf '%s\037%s\037%s\037%s\037%s\n' \
  "${GH_STUB_PRIVATE-true}" "${GH_STUB_VISIBILITY-PRIVATE}" \
  "${GH_STUB_URL-}" "${GH_STUB_NAME-owner/backup}" "${GH_STUB_BRANCH-main}"
GHEOF
  chmod +x "$fakebin/gh"
  printf '%s\n' "$dir"
}

# Run the command for a case with that case's environment.
run_case() { # <case-dir> <args...>
  local dir=$1
  shift
  PATH="$dir/fakebin:$PATH" \
    GH_STUB_URL="$dir/bare.git" \
    FM_HOME="$dir/homes/main" \
    FM_ROOT_OVERRIDE="$dir/fmroot" \
    FM_HOME_BACKUP_CONFIG="$dir/cfg" \
    FM_HOME_BACKUP_WORKDIR="$dir/work" \
    "$BACKUP" "$@" 2>&1
}

# Files present in the pushed remote, one path per line.
remote_files() { # <case-dir>
  git -C "$1/bare.git" ls-tree -r --name-only refs/heads/main 2> /dev/null
}

remote_commits() { # <case-dir>
  git -C "$1/bare.git" rev-list --count refs/heads/main 2> /dev/null || printf '0\n'
}

# Replace one home's MANIFEST in the pushed remote. Restore resets its clone
# hard to origin on every run, so this is how a case gets a manifest the tool
# itself would never write.
push_manifest() { # <case-dir> <home-id> <manifest-body>
  local dir=$1 id=$2 body=$3 work
  work=$(mktemp -d "$TMP_ROOT/tamper.XXXXXX") || fail 'could not create a tamper clone'
  git clone -q "$dir/bare.git" "$work" 2> /dev/null || fail 'could not clone the backup remote'
  printf '%s' "$body" > "$work/$id/MANIFEST" || fail "no $id in the backup remote to re-manifest"
  git -C "$work" add -A
  git -C "$work" -c user.name=t -c user.email=t@l commit -qm 'rewrite manifest'
  git -C "$work" push -q origin HEAD:refs/heads/main
  rm -rf "$work"
}

register_secondmate() { # <case-dir> <id> <home-dir> [host root]
  local dir=$1 id=$2 home=$3 host=${4:-} root=${5:-}
  local reg="$dir/homes/main/data/secondmates.md"
  if [ -n "$host" ]; then
    printf -- '- %s - a remote mate (host: %s; root: %s; home: %s; scope: things; projects: alpha; added 2026-08-20)\n' \
      "$id" "$host" "$root" "$home" >> "$reg"
  else
    printf -- '- %s - a local mate (home: %s; scope: things; projects: alpha; added 2026-08-20)\n' \
      "$id" "$home" >> "$reg"
  fi
}

# --- usage and argument handling --------------------------------------------

test_help_describes_both_verbs() {
  local out rc=0
  out=$("$BACKUP" --help) || rc=$?
  expect_code 0 "$rc" '--help'
  assert_contains "$out" 'fm-home-backup.sh backup' '--help omits the backup usage line'
  assert_contains "$out" 'fm-home-backup.sh restore --home <id> --into <dir>' \
    '--help omits the restore usage line'
  pass 'fm-home-backup.sh: --help documents both verbs'
}

test_bad_invocations_exit_two() {
  local dir rc
  dir=$(new_case)
  rc=0
  run_case "$dir" > /dev/null 2>&1 || rc=$?
  expect_code 2 "$rc" 'no verb'
  rc=0
  run_case "$dir" sync > /dev/null 2>&1 || rc=$?
  expect_code 2 "$rc" 'unknown verb'
  rc=0
  run_case "$dir" backup --wat > /dev/null 2>&1 || rc=$?
  expect_code 2 "$rc" 'unknown backup option'
  rc=0
  run_case "$dir" backup --dry-run --dry-run > /dev/null 2>&1 || rc=$?
  expect_code 2 "$rc" 'repeated --dry-run'
  rc=0
  run_case "$dir" restore --into /tmp/x > /dev/null 2>&1 || rc=$?
  expect_code 2 "$rc" 'restore without --home'
  rc=0
  run_case "$dir" restore --home main > /dev/null 2>&1 || rc=$?
  expect_code 2 "$rc" 'restore without --into'
  rc=0
  run_case "$dir" restore --home main --into relative/path > /dev/null 2>&1 || rc=$?
  expect_code 2 "$rc" 'restore with a relative --into'
  rc=0
  run_case "$dir" restore --home 'bad id' --into /tmp/x > /dev/null 2>&1 || rc=$?
  expect_code 2 "$rc" 'restore with an invalid home id'
  pass 'fm-home-backup.sh: every malformed invocation exits 2'
}

# --- configuration refusals -------------------------------------------------

test_unconfigured_target_refuses_with_setup_steps() {
  local dir out rc=0
  dir=$(new_case)
  rm -f "$dir/cfg/target"
  out=$(run_case "$dir" backup) || rc=$?
  expect_code 1 "$rc" 'unconfigured target'
  assert_contains "$out" 'no backup target configured' 'refusal did not name the missing target'
  assert_contains "$out" 'gh repo create' 'refusal did not print the repo creation step'
  assert_contains "$out" "$dir/cfg/target" 'refusal did not print where to write the target'
  expect_code 0 "$(remote_commits "$dir")" 'unconfigured target still pushed'
  pass 'fm-home-backup.sh: an unconfigured target refuses with the exact setup steps'
}

test_malformed_target_refuses() {
  local dir out rc=0
  dir=$(new_case)
  printf 'https://github.com/owner/backup.git\n' > "$dir/cfg/target"
  out=$(run_case "$dir" backup) || rc=$?
  expect_code 1 "$rc" 'malformed target'
  assert_contains "$out" 'must hold one GitHub owner/repo slug' 'refusal did not explain the expected form'
  pass 'fm-home-backup.sh: a target that is not an owner/repo slug refuses'
}

test_unresolved_home_refuses() {
  local dir out rc=0
  dir=$(new_case)
  out=$(PATH="$dir/fakebin:$PATH" GH_STUB_URL="$dir/bare.git" \
    FM_ROOT_OVERRIDE="$dir/fmroot" FM_HOME_BACKUP_CONFIG="$dir/cfg" \
    FM_HOME_BACKUP_WORKDIR="$dir/work" HOME="$dir/nohome" \
    "$BACKUP" backup 2>&1) || rc=$?
  expect_code 1 "$rc" 'unresolved home'
  assert_contains "$out" 'no firstmate home resolved' 'refusal did not name the unresolved home'
  assert_contains "$out" "$dir/cfg/home" 'refusal did not print where to record the home'
  pass 'fm-home-backup.sh: an unresolved FM_HOME refuses instead of guessing'
}

test_secondmate_home_as_fm_home_refuses() {
  local dir out rc=0
  dir=$(new_case)
  printf 'quartermaster\n' > "$dir/homes/main/.fm-secondmate-home"
  out=$(run_case "$dir" backup) || rc=$?
  expect_code 1 "$rc" 'secondmate home as FM_HOME'
  assert_contains "$out" 'is a secondmate home' 'refusal did not identify the home kind'
  expect_code 0 "$(remote_commits "$dir")" 'a secondmate FM_HOME still pushed'
  pass 'fm-home-backup.sh: pointing FM_HOME at a secondmate home refuses'
}

# --- target privacy ---------------------------------------------------------

test_public_target_refuses_and_pushes_nothing() {
  local dir out rc=0
  dir=$(new_case)
  out=$(GH_STUB_PRIVATE=false GH_STUB_VISIBILITY=PUBLIC run_case "$dir" backup) || rc=$?
  expect_code 1 "$rc" 'public target'
  assert_contains "$out" 'is not private' 'refusal did not say the repo is not private'
  assert_contains "$out" 'gh repo edit' 'refusal did not print the remediation command'
  expect_code 0 "$(remote_commits "$dir")" 'a public target was pushed to'
  pass 'fm-home-backup.sh: a public target refuses and pushes nothing'
}

test_internal_and_unset_visibility_refuse() {
  local dir rc
  dir=$(new_case)
  rc=0
  GH_STUB_PRIVATE=true GH_STUB_VISIBILITY=INTERNAL run_case "$dir" backup > /dev/null 2>&1 || rc=$?
  expect_code 1 "$rc" 'internal visibility'
  rc=0
  GH_STUB_PRIVATE=true GH_STUB_VISIBILITY='' run_case "$dir" backup > /dev/null 2>&1 || rc=$?
  expect_code 1 "$rc" 'missing visibility'
  rc=0
  GH_STUB_PRIVATE='' GH_STUB_VISIBILITY=PRIVATE run_case "$dir" backup > /dev/null 2>&1 || rc=$?
  expect_code 1 "$rc" 'missing isPrivate'
  expect_code 0 "$(remote_commits "$dir")" 'an unconfirmed visibility was pushed to'
  pass 'fm-home-backup.sh: privacy needs both signals, so a missing field never reads as private'
}

test_unreadable_target_refuses() {
  local dir out rc=0
  dir=$(new_case)
  out=$(GH_STUB_FAIL=1 run_case "$dir" backup) || rc=$?
  expect_code 1 "$rc" 'gh failure'
  assert_contains "$out" 'privacy could not be confirmed' 'refusal did not attribute the failure to privacy'
  expect_code 0 "$(remote_commits "$dir")" 'an unreadable target was pushed to'
  pass 'fm-home-backup.sh: a target gh cannot read refuses rather than pushing blind'
}

test_slug_mismatch_refuses() {
  local dir out rc=0
  dir=$(new_case)
  out=$(GH_STUB_NAME=someone/else run_case "$dir" backup) || rc=$?
  expect_code 1 "$rc" 'slug mismatch'
  assert_contains "$out" 'refusing to act on a repo other than the configured one' \
    'refusal did not explain the slug mismatch'
  pass 'fm-home-backup.sh: gh resolving a different repo than configured refuses'
}

# --- capture ----------------------------------------------------------------

test_backup_captures_allowlisted_trees_only() {
  local dir out files rc=0
  dir=$(new_case)
  mkdir -p "$dir/homes/beta"
  make_home "$dir/homes/beta" beta
  printf 'beta memory\n' > "$dir/homes/beta/data/learnings.md"
  register_secondmate "$dir" beta "$dir/homes/beta"

  out=$(run_case "$dir" backup) || rc=$?
  expect_code 0 "$rc" 'backup'
  assert_contains "$out" 'pushed to owner/backup' 'backup did not report a push'

  files=$(remote_files "$dir")
  assert_contains "$files" 'main/data/backlog.md' 'the primary home data was not stored'
  assert_contains "$files" 'main/config/backend' 'the primary home config was not stored'
  assert_contains "$files" 'beta/data/learnings.md' 'the secondmate home data was not stored'
  assert_contains "$files" 'main/MANIFEST' 'the primary manifest was not stored'
  assert_contains "$files" 'SNAPSHOT' 'the fleet snapshot was not stored'
  assert_contains "$files" 'README.md' 'the readme was not stored'
  assert_not_contains "$files" 'main/state' 'state/ leaked into the backup'
  assert_not_contains "$files" 'main/projects' 'projects/ leaked into the backup'
  assert_not_contains "$files" '.env' '.env leaked into the backup'
  pass 'fm-home-backup.sh: captures data/ and config/ per home, and nothing else'
}

test_backup_never_writes_into_a_home() {
  local dir before_main before_beta rc=0
  dir=$(new_case)
  mkdir -p "$dir/homes/beta"
  make_home "$dir/homes/beta" beta
  register_secondmate "$dir" beta "$dir/homes/beta"
  before_main=$(home_fingerprint "$dir/homes/main")
  before_beta=$(home_fingerprint "$dir/homes/beta")

  run_case "$dir" backup > /dev/null 2>&1 || rc=$?
  expect_code 0 "$rc" 'backup'

  [ "$before_main" = "$(home_fingerprint "$dir/homes/main")" ] \
    || fail 'backup changed the primary home'
  [ "$before_beta" = "$(home_fingerprint "$dir/homes/beta")" ] \
    || fail 'backup changed a secondmate home'
  pass 'fm-home-backup.sh: backup leaves every home byte-for-byte untouched'
}

test_second_run_is_a_clean_no_op() {
  local dir out rc=0
  dir=$(new_case)
  run_case "$dir" backup > /dev/null 2>&1 || fail 'first backup failed'
  expect_code 1 "$(remote_commits "$dir")" 'first backup did not commit once'
  out=$(run_case "$dir" backup) || rc=$?
  expect_code 0 "$rc" 'second backup'
  assert_contains "$out" 'no changes' 'an unchanged fleet still reported work'
  expect_code 1 "$(remote_commits "$dir")" 'an unchanged fleet produced a second commit'

  printf 'new note\n' > "$dir/homes/main/data/note.md"
  run_case "$dir" backup > /dev/null 2>&1 || fail 'third backup failed'
  expect_code 2 "$(remote_commits "$dir")" 'a changed fleet did not produce a commit'
  pass 'fm-home-backup.sh: an unchanged fleet is a no-op, a changed one commits once'
}

test_dry_run_reports_without_publishing() {
  local dir out rc=0
  dir=$(new_case)
  out=$(run_case "$dir" backup --dry-run) || rc=$?
  expect_code 0 "$rc" 'dry run'
  assert_contains "$out" 'would commit and push to owner/backup' 'dry run did not report the pending change'
  expect_code 0 "$(remote_commits "$dir")" 'dry run pushed'
  pass 'fm-home-backup.sh: --dry-run reports the pending snapshot and publishes nothing'
}

test_empty_directories_and_modes_survive_the_round_trip() {
  local dir into rc=0 mode
  dir=$(new_case)
  mkdir -p "$dir/homes/main/data/empty-task"
  chmod 700 "$dir/homes/main/data/empty-task"
  chmod 600 "$dir/homes/main/config/backend"
  run_case "$dir" backup > /dev/null 2>&1 || fail 'backup failed'

  into="$dir/restored"
  mkdir -p "$into"
  run_case "$dir" restore --home main --into "$into" --apply > /dev/null 2>&1 || rc=$?
  expect_code 0 "$rc" 'restore --apply'
  [ -d "$into/data/empty-task" ] || fail 'an empty directory did not survive the round trip'
  mode=$(stat -f '%Lp' "$into/config/backend" 2> /dev/null || stat -c '%a' "$into/config/backend")
  [ "$mode" = 600 ] || fail "a 0600 file was restored as $mode"
  mode=$(stat -f '%Lp' "$into/data/empty-task" 2> /dev/null || stat -c '%a' "$into/data/empty-task")
  [ "$mode" = 700 ] || fail "a 0700 directory was restored as $mode"
  pass 'fm-home-backup.sh: empty directories and exact modes survive backup and restore'
}

test_a_present_but_empty_tree_survives_the_round_trip() {
  local dir into rc=0
  dir=$(new_case)
  rm -f "$dir/homes/main/config/backend"
  run_case "$dir" backup > /dev/null 2>&1 || fail 'backup failed'

  into="$dir/restored"
  mkdir -p "$into"
  run_case "$dir" restore --home main --into "$into" --apply > /dev/null 2>&1 || rc=$?
  expect_code 0 "$rc" 'restore of a home with an empty captured tree'
  [ -d "$into/config" ] || fail 'a present but empty tree did not survive the round trip'
  [ -z "$(ls -A -- "$into/config")" ] || fail 'an empty tree came back with content'
  assert_present "$into/data/backlog.md" 'the populated tree was lost alongside the empty one'
  pass 'fm-home-backup.sh: a captured tree that is present but empty restores as an empty tree'
}

# --- refusals on unexpected shapes ------------------------------------------

test_symlink_inside_a_captured_tree_refuses() {
  local dir out rc=0
  dir=$(new_case)
  ln -s /etc/hosts "$dir/homes/main/data/linked"
  out=$(run_case "$dir" backup) || rc=$?
  expect_code 1 "$rc" 'symlink in data/'
  assert_contains "$out" 'refusing symlink' 'refusal did not name the symlink'
  expect_code 0 "$(remote_commits "$dir")" 'a symlinked tree was pushed'
  pass 'fm-home-backup.sh: a symlink inside a captured tree refuses'
}

test_credential_shaped_file_refuses_until_acknowledged() {
  local dir out rc=0
  dir=$(new_case)
  printf 'TOKEN=hunter2\n' > "$dir/homes/main/data/.env"
  out=$(run_case "$dir" backup) || rc=$?
  expect_code 1 "$rc" 'credential-shaped file'
  assert_contains "$out" 'credential-shaped' 'refusal did not classify the file'
  assert_contains "$out" 'main/data/.env' 'refusal did not print the ack line to add'
  expect_code 0 "$(remote_commits "$dir")" 'a credential-shaped file was pushed'

  printf 'main/data/.env\n' > "$dir/cfg/ack"
  rc=0
  run_case "$dir" backup > /dev/null 2>&1 || rc=$?
  expect_code 0 "$rc" 'backup after acknowledgement'
  assert_contains "$(remote_files "$dir")" 'main/data/.env' 'an acknowledged file was still dropped'
  pass 'fm-home-backup.sh: a credential-shaped file refuses, and only an explicit ack lets it through'
}

test_envrc_refuses_until_acknowledged() {
  local dir out rc=0
  dir=$(new_case)
  printf 'export AWS_SECRET_ACCESS_KEY=hunter2\n' > "$dir/homes/main/config/.envrc"
  out=$(run_case "$dir" backup) || rc=$?
  expect_code 1 "$rc" 'direnv file'
  assert_contains "$out" 'credential-shaped' 'refusal did not classify the direnv file'
  assert_contains "$out" 'main/config/.envrc' 'refusal did not print the ack line to add'
  expect_code 0 "$(remote_commits "$dir")" 'a direnv file was pushed'

  printf 'main/config/.envrc\n' > "$dir/cfg/ack"
  rc=0
  run_case "$dir" backup > /dev/null 2>&1 || rc=$?
  expect_code 0 "$rc" 'backup after acknowledgement'
  assert_contains "$(remote_files "$dir")" 'main/config/.envrc' 'an acknowledged direnv file was still dropped'
  pass 'fm-home-backup.sh: a .envrc is credential-shaped, so it refuses until acknowledged'
}

test_backup_repo_gitignore_refuses() {
  local dir out rc=0 seed
  dir=$(new_case)
  seed="$dir/seed"
  git clone -q "$dir/bare.git" "$seed" 2> /dev/null
  printf '*.md\n' > "$seed/.gitignore"
  git -C "$seed" add -A
  git -C "$seed" -c user.name=t -c user.email=t@l commit -qm 'ignore markdown'
  git -C "$seed" push -q origin HEAD:refs/heads/main

  out=$(run_case "$dir" backup) || rc=$?
  expect_code 1 "$rc" 'ignored captured files'
  assert_contains "$out" 'excludes captured files' 'refusal did not explain the ignore rule'
  pass 'fm-home-backup.sh: a backup repo that would silently drop captured files refuses'
}

test_registry_id_colliding_with_the_primary_refuses() {
  local dir out rc=0
  dir=$(new_case)
  mkdir -p "$dir/homes/other"
  make_home "$dir/homes/other" main
  register_secondmate "$dir" main "$dir/homes/other"
  out=$(run_case "$dir" backup) || rc=$?
  expect_code 1 "$rc" 'id collision'
  assert_contains "$out" 'collides with the primary' 'refusal did not explain the collision'
  pass 'fm-home-backup.sh: a secondmate registered as "main" refuses rather than merging homes'
}

test_malformed_registry_refuses() {
  local dir out rc=0
  dir=$(new_case)
  printf -- '- broken - missing every field\n' > "$dir/homes/main/data/secondmates.md"
  out=$(run_case "$dir" backup) || rc=$?
  expect_code 1 "$rc" 'malformed registry'
  assert_contains "$out" 'secondmate registry' 'refusal did not name the registry'
  expect_code 0 "$(remote_commits "$dir")" 'a malformed registry still pushed a partial fleet'
  pass 'fm-home-backup.sh: a malformed secondmate registry refuses instead of half-reading it'
}

# --- remote secondmates -----------------------------------------------------

test_remote_secondmate_is_named_not_skipped() {
  local dir out rc=0 files
  dir=$(new_case)
  register_secondmate "$dir" faraway /srv/homes/faraway squallbox /srv/firstmate
  out=$(run_case "$dir" backup) || rc=$?
  expect_code 3 "$rc" 'remote secondmate'
  assert_contains "$out" 'NOT captured' 'the run did not say the remote home was missed'
  assert_contains "$out" 'faraway' 'the run did not name the missed home'
  files=$(remote_files "$dir")
  assert_contains "$files" 'main/data/backlog.md' 'local homes were dropped because a remote home exists'
  git -C "$dir/bare.git" show "refs/heads/main:SNAPSHOT" > "$dir/snapshot.txt"
  assert_grep 'unsupported-remote faraway squallbox /srv/homes/faraway' "$dir/snapshot.txt" \
    'SNAPSHOT does not record the uncaptured remote home'
  pass 'fm-home-backup.sh: a remote secondmate is captured nowhere, named everywhere, and exits 3'
}

# --- unusable local secondmate homes ----------------------------------------

test_unusable_local_secondmate_is_skipped_not_fatal() {
  local dir out rc=0 files
  dir=$(new_case)
  mkdir -p "$dir/homes/beta"
  make_home "$dir/homes/beta" beta
  printf 'beta memory\n' > "$dir/homes/beta/data/learnings.md"
  register_secondmate "$dir" beta "$dir/homes/beta"
  # One home the captain moved away, one that exists but was never seeded.
  register_secondmate "$dir" gone "$dir/homes/gone"
  mkdir -p "$dir/homes/unseeded"
  make_home "$dir/homes/unseeded"
  register_secondmate "$dir" unseeded "$dir/homes/unseeded"

  out=$(run_case "$dir" backup) || rc=$?
  expect_code 3 "$rc" 'unusable local secondmate'
  assert_contains "$out" 'NOT captured' 'the run did not say a home was missed'
  assert_contains "$out" "$dir/homes/gone" 'the run did not name the missing home'
  assert_contains "$out" "$dir/homes/unseeded" 'the run did not name the unseeded home'

  files=$(remote_files "$dir")
  assert_contains "$files" 'main/data/backlog.md' 'the primary home was dropped because one secondmate was unusable'
  assert_contains "$files" 'main/config/backend' 'the primary config was dropped because one secondmate was unusable'
  assert_contains "$files" 'beta/data/learnings.md' 'a healthy secondmate was dropped alongside the unusable one'
  assert_not_contains "$files" 'gone/' 'an unusable home was captured anyway'
  assert_not_contains "$files" 'unseeded/' 'an unseeded home was captured anyway'

  git -C "$dir/bare.git" show 'refs/heads/main:SNAPSHOT' > "$dir/snapshot.txt"
  assert_grep "uncaptured-home gone $dir/homes/gone" "$dir/snapshot.txt" \
    'SNAPSHOT does not record the uncaptured local home'
  assert_grep 'not a directory' "$dir/snapshot.txt" \
    'SNAPSHOT does not record why the missing home was uncaptured'
  assert_grep 'not a seeded secondmate home' "$dir/snapshot.txt" \
    'SNAPSHOT does not record why the unseeded home was uncaptured'
  assert_grep 'home main ' "$dir/snapshot.txt" \
    'SNAPSHOT does not record the primary home it did capture'
  assert_grep 'home beta ' "$dir/snapshot.txt" \
    'SNAPSHOT does not record the healthy secondmate it did capture'
  pass 'fm-home-backup.sh: an unusable local home is skipped loudly while every other home is still pushed'
}

# --- concurrency ------------------------------------------------------------

test_a_live_lock_makes_the_run_a_no_op() {
  local dir out rc=0 ident
  dir=$(new_case)
  mkdir -p "$dir/work/lock"
  ident=$(ps -o lstart= -p $$ | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
  printf '%s\n%s\n' "$$" "$ident" > "$dir/work/lock/owner"
  out=$(run_case "$dir" backup) || rc=$?
  expect_code 0 "$rc" 'concurrent run'
  assert_contains "$out" 'another run holds' 'the concurrent run did not explain itself'
  expect_code 0 "$(remote_commits "$dir")" 'a concurrent run pushed anyway'
  [ -d "$dir/work/lock" ] || fail 'the concurrent run removed a live lock'
  pass 'fm-home-backup.sh: a second concurrent run takes no action and exits 0'
}

# The two verbs answer the same live lock differently on purpose, so both halves
# are asserted here: a scheduled backup overlapping is not a failure, but a
# recovery that wrote nothing must never read as one that succeeded.
test_a_live_lock_no_ops_backup_but_refuses_restore() {
  local dir out rc=0 ident
  dir=$(new_case)
  run_case "$dir" backup > /dev/null 2>&1 || fail 'backup failed'
  mkdir -p "$dir/restored"
  mkdir -p "$dir/work/lock"
  ident=$(ps -o lstart= -p $$ | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
  printf '%s\n%s\n' "$$" "$ident" > "$dir/work/lock/owner"

  out=$(run_case "$dir" backup) || rc=$?
  expect_code 0 "$rc" 'backup under a live lock'
  assert_contains "$out" 'another run holds' 'the concurrent backup did not explain itself'

  rc=0
  out=$(run_case "$dir" restore --home main --into "$dir/restored" --apply) || rc=$?
  expect_code 1 "$rc" 'restore --apply under a live lock'
  assert_contains "$out" "$dir/work/lock" 'the refusal did not name the lock'
  assert_contains "$out" "$$" 'the refusal did not name the pid holding the lock'
  assert_absent "$dir/restored/data" 'a refused restore wrote anyway'

  rc=0
  out=$(run_case "$dir" restore --home main --into "$dir/restored") || rc=$?
  expect_code 1 "$rc" 'plan-only restore under a live lock'
  assert_contains "$out" "$dir/work/lock" 'the plan-only refusal did not name the lock'

  [ -d "$dir/work/lock" ] || fail 'a refused run removed a live lock'
  pass 'fm-home-backup.sh: a live lock is a no-op for backup and a non-zero refusal for restore'
}

test_a_stale_lock_is_broken() {
  local dir rc=0
  dir=$(new_case)
  mkdir -p "$dir/work/lock"
  printf '%s\n%s\n' 999999 'Thu Jan  1 00:00:00 1970' > "$dir/work/lock/owner"
  run_case "$dir" backup > /dev/null 2>&1 || rc=$?
  expect_code 0 "$rc" 'stale lock'
  expect_code 1 "$(remote_commits "$dir")" 'a stale lock blocked the backup'
  pass 'fm-home-backup.sh: a lock whose owner is gone is broken instead of wedging every run'
}

# --- restore ----------------------------------------------------------------

test_restore_prints_the_plan_and_writes_nothing() {
  local dir out into rc=0
  dir=$(new_case)
  run_case "$dir" backup > /dev/null 2>&1 || fail 'backup failed'
  into="$dir/restored"
  mkdir -p "$into"
  out=$(run_case "$dir" restore --home main --into "$into") || rc=$?
  expect_code 0 "$rc" 'restore plan'
  assert_contains "$out" "place  644  $into/data/backlog.md" 'the plan did not say what goes where'
  assert_contains "$out" 'nothing was written' 'the plan did not say it wrote nothing'
  assert_absent "$into/data" 'a plan-only restore created files'
  pass 'fm-home-backup.sh: restore without --apply prints the full plan and writes nothing'
}

test_restore_refuses_a_populated_home_without_force() {
  local dir out into rc=0
  dir=$(new_case)
  run_case "$dir" backup > /dev/null 2>&1 || fail 'backup failed'
  into="$dir/restored"
  mkdir -p "$into/data"
  printf 'do not lose me\n' > "$into/data/precious.md"
  out=$(run_case "$dir" restore --home main --into "$into" --apply) || rc=$?
  expect_code 1 "$rc" 'populated restore target'
  assert_contains "$out" 'already has content' 'refusal did not explain the clobber'
  assert_contains "$out" '--force' 'refusal did not name the flag that overrides it'
  assert_present "$into/data/precious.md" 'a refused restore still clobbered the home'

  rc=0
  run_case "$dir" restore --home main --into "$into" --apply --force > /dev/null 2>&1 || rc=$?
  expect_code 0 "$rc" 'forced restore'
  assert_absent "$into/data/precious.md" '--force did not replace the tree'
  assert_present "$into/data/backlog.md" '--force did not restore the backed-up tree'
  pass 'fm-home-backup.sh: restore refuses to clobber a populated home without --force'
}

test_restore_leaves_state_and_projects_alone() {
  local dir into rc=0
  dir=$(new_case)
  run_case "$dir" backup > /dev/null 2>&1 || fail 'backup failed'
  into="$dir/homes/main"
  run_case "$dir" restore --home main --into "$into" --apply --force > /dev/null 2>&1 || rc=$?
  expect_code 0 "$rc" 'restore over a live home'
  assert_present "$into/state/live.json" 'restore removed state/'
  assert_present "$into/projects/someclone/README.md" 'restore removed projects/'
  assert_present "$into/.env" 'restore removed an unrelated home file'
  pass 'fm-home-backup.sh: restore writes only data/ and config/, never state/ or projects/'
}

test_restore_refuses_a_missing_destination_or_home() {
  local dir out rc=0
  dir=$(new_case)
  run_case "$dir" backup > /dev/null 2>&1 || fail 'backup failed'
  out=$(run_case "$dir" restore --home main --into "$dir/nowhere" --apply) || rc=$?
  expect_code 1 "$rc" 'missing destination'
  assert_contains "$out" 'does not exist' 'refusal did not name the missing destination'
  assert_contains "$out" 'mkdir -p' 'refusal did not print the remediation'
  rc=0
  out=$(run_case "$dir" restore --home ghost --into "$dir" ) || rc=$?
  expect_code 1 "$rc" 'unknown home'
  assert_contains "$out" "no home 'ghost'" 'refusal did not name the unknown home'
  assert_contains "$out" 'Available: main' 'refusal did not list the homes that do exist'
  pass 'fm-home-backup.sh: restore refuses an absent destination and an unknown home id'
}

test_restore_refuses_a_manifest_that_escapes_the_destination() {
  local dir out rc=0 into
  dir=$(new_case)
  run_case "$dir" backup > /dev/null 2>&1 || fail 'backup failed'
  into="$dir/restored"
  mkdir -p "$into"

  push_manifest "$dir" main '# fm-home-backup manifest v1
home main
source /somewhere
tree data present
f 644 ../escaped.md
'
  rc=0
  out=$(run_case "$dir" restore --home main --into "$into" --apply --force) || rc=$?
  expect_code 1 "$rc" 'manifest carrying a .. component'
  assert_contains "$out" 'walks out of the destination' 'refusal did not name the traversal'
  assert_contains "$out" '../escaped.md' 'refusal did not name the offending entry'
  assert_absent "$dir/escaped.md" 'a traversing manifest wrote outside the destination'

  push_manifest "$dir" main "# fm-home-backup manifest v1
home main
source /somewhere
tree data present
f 644 $dir/escaped-abs.md
"
  rc=0
  out=$(run_case "$dir" restore --home main --into "$into" --apply --force) || rc=$?
  expect_code 1 "$rc" 'manifest carrying an absolute path'
  assert_contains "$out" 'is not a relative path' 'refusal did not reject the absolute path'
  assert_absent "$dir/escaped-abs.md" 'an absolute manifest path wrote outside the destination'

  push_manifest "$dir" main '# fm-home-backup manifest v1
home main
source /somewhere
tree state present
d 755 state/live
'
  rc=0
  out=$(run_case "$dir" restore --home main --into "$into" --apply --force) || rc=$?
  expect_code 1 "$rc" 'manifest claiming a tree outside the allowlist'
  assert_contains "$out" 'never captures' 'refusal did not reject the unlisted tree'
  assert_absent "$into/state" 'restore created a tree it never captures'

  push_manifest "$dir" main '# fm-home-backup manifest v1
home main
source /somewhere
tree data present
f 644 config/backend
'
  rc=0
  out=$(run_case "$dir" restore --home main --into "$into" --apply --force) || rc=$?
  expect_code 1 "$rc" 'manifest entry outside its own captured trees'
  assert_contains "$out" 'not inside a captured tree of this home' \
    'refusal did not reject an entry outside the trees the manifest declared'
  assert_absent "$into/config" 'restore placed a tree the manifest never declared'

  assert_absent "$into/data" 'a refused restore wrote into the destination'
  pass 'fm-home-backup.sh: restore refuses a MANIFEST that would write outside the destination'
}

test_restore_refuses_an_interrupted_restores_rescue_copy() {
  local dir out rc=0 into
  dir=$(new_case)
  run_case "$dir" backup > /dev/null 2>&1 || fail 'backup failed'
  into="$dir/restored"
  mkdir -p "$into/.fm-home-backup-restore/previous/data"
  printf 'the tree an interrupted restore moved aside\n' \
    > "$into/.fm-home-backup-restore/previous/data/backlog.md"

  out=$(run_case "$dir" restore --home main --into "$into" --apply) || rc=$?
  expect_code 1 "$rc" 'restore over an interrupted one'
  assert_contains "$out" '.fm-home-backup-restore' 'refusal did not name the rescue directory'
  assert_present "$into/.fm-home-backup-restore/previous/data/backlog.md" \
    'the refusal destroyed the rescue copy it refused over'
  assert_absent "$into/data" 'a refused restore wrote anyway'
  pass 'fm-home-backup.sh: restore refuses over an interrupted restore rather than overwriting its rescue copy'
}

test_restore_leaves_no_scratch_behind_on_success() {
  local dir rc=0 into
  dir=$(new_case)
  run_case "$dir" backup > /dev/null 2>&1 || fail 'backup failed'
  into="$dir/restored"
  mkdir -p "$into/data"
  printf 'replace me\n' > "$into/data/stale.md"
  run_case "$dir" restore --home main --into "$into" --apply --force > /dev/null 2>&1 || rc=$?
  expect_code 0 "$rc" 'forced restore'
  assert_present "$into/data/backlog.md" 'the restored tree is missing'
  assert_absent "$into/data/stale.md" 'the replaced tree was merged rather than swapped'
  assert_absent "$into/.fm-home-backup-restore" 'a successful restore left its staging area behind'
  pass 'fm-home-backup.sh: a successful restore removes its staging area and the tree it moved aside'
}

test_restore_reports_visibility_rather_than_gating_on_it() {
  local dir out rc=0
  dir=$(new_case)
  run_case "$dir" backup > /dev/null 2>&1 || fail 'backup failed'
  out=$(GH_STUB_PRIVATE=false GH_STUB_VISIBILITY=PUBLIC run_case "$dir" restore --home main --into "$dir") || rc=$?
  expect_code 0 "$rc" 'restore from a repo whose visibility drifted'
  assert_contains "$out" '(PUBLIC)' 'restore did not report the visibility it saw'
  pass 'fm-home-backup.sh: restore reports visibility rather than gating a recovery on it'
}

test_help_describes_both_verbs
test_bad_invocations_exit_two
test_unconfigured_target_refuses_with_setup_steps
test_malformed_target_refuses
test_unresolved_home_refuses
test_secondmate_home_as_fm_home_refuses
test_public_target_refuses_and_pushes_nothing
test_internal_and_unset_visibility_refuse
test_unreadable_target_refuses
test_slug_mismatch_refuses
test_backup_captures_allowlisted_trees_only
test_backup_never_writes_into_a_home
test_second_run_is_a_clean_no_op
test_dry_run_reports_without_publishing
test_empty_directories_and_modes_survive_the_round_trip
test_a_present_but_empty_tree_survives_the_round_trip
test_symlink_inside_a_captured_tree_refuses
test_credential_shaped_file_refuses_until_acknowledged
test_envrc_refuses_until_acknowledged
test_backup_repo_gitignore_refuses
test_registry_id_colliding_with_the_primary_refuses
test_malformed_registry_refuses
test_remote_secondmate_is_named_not_skipped
test_unusable_local_secondmate_is_skipped_not_fatal
test_a_live_lock_makes_the_run_a_no_op
test_a_live_lock_no_ops_backup_but_refuses_restore
test_a_stale_lock_is_broken
test_restore_prints_the_plan_and_writes_nothing
test_restore_refuses_a_populated_home_without_force
test_restore_leaves_state_and_projects_alone
test_restore_refuses_a_missing_destination_or_home
test_restore_refuses_a_manifest_that_escapes_the_destination
test_restore_refuses_an_interrupted_restores_rescue_copy
test_restore_leaves_no_scratch_behind_on_success
test_restore_reports_visibility_rather_than_gating_on_it
