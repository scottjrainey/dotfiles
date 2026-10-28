#!/usr/bin/env bash
# Behavior tests for aerospace-workspace-float-toggle.
#
# Fakes the aerospace CLI on PATH (tests/aerospace-fakes.sh) and points the
# state dir at a temp root, so no AeroSpace is needed and ~/.cache is untouched.
set -u

# shellcheck source=tests/lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
# shellcheck source=tests/aerospace-fakes.sh
. "$(dirname "${BASH_SOURCE[0]}")/aerospace-fakes.sh"

SCRIPT="$FM_BIN_DIR/aerospace-workspace-float-toggle"
[ -x "$SCRIPT" ] || fail "aerospace-workspace-float-toggle is missing or not executable at $SCRIPT"

TMP_ROOT=$(fm_test_tmproot aerospace-float-toggle) || fail "could not create a temp root"

run() { # <case-dir> <state-dir> <args...>
  local dir=$1 state=$2
  shift 2
  AEROSPACE_FLOAT_TOGGLE_STATE_DIR="$state" PATH="$dir/fakebin:$PATH" "$SCRIPT" "$@" > "$dir/out" 2>&1
}

new_case() { # <workspace> <windows: lines of "id<TAB>layout">
  local d
  d=$(aerospace_case "$TMP_ROOT")
  printf '%s\n' "$1" > "$d/workspace"
  printf '%b' "$2" > "$d/list-windows"
  printf '%s\n' "$d"
}

# --- arguments fail closed --------------------------------------------------

d=$(new_case editor "")
run "$d" "$d/state" --help
expect_code 0 $? "--help"
assert_contains "$(cat "$d/out")" "Usage: aerospace-workspace-float-toggle" "--help prints usage"
run "$d" "$d/state" --bogus
expect_code 2 $? "--bogus"
[ ! -s "$d/calls" ] || fail "--help/--bogus must not call aerospace"
pass "--help exits 0 and an unknown argument exits 2, neither calling aerospace"

# --- float, then restore exactly what was floated ---------------------------

STATE="$TMP_ROOT/state-roundtrip"
d=$(new_case editor '1\th_tiles\n2\tfloating\n3\tv_accordion\n')
run "$d" "$STATE"
expect_code 0 $? "first press"
calls=$(calls_of "$d")
assert_contains "$calls" "list-windows --workspace focused --format %{window-id}%{tab}%{window-layout}" "first press lists the focused workspace"
assert_contains "$calls" "layout --window-id 1 floating" "first press floats tiled window 1"
assert_contains "$calls" "layout --window-id 3 floating" "first press floats accordion window 3"
assert_not_contains "$calls" "layout --window-id 2" "first press leaves already-floating window 2 alone"
[ "$(cat "$STATE/editor")" = $'1\n3' ] || fail "first press records exactly the floated ids (got: $(cat "$STATE/editor"))"
pass "first press floats every tiled window and records only those"

d=$(new_case editor '1\tfloating\n2\tfloating\n3\tfloating\n')
run "$d" "$STATE"
expect_code 0 $? "second press"
calls=$(calls_of "$d")
assert_contains "$calls" "layout --window-id 1 tiling" "second press re-tiles window 1"
assert_contains "$calls" "layout --window-id 3 tiling" "second press re-tiles window 3"
assert_not_contains "$calls" "layout --window-id 2" "second press leaves the originally floating window 2 floating"
assert_absent "$STATE/editor" "second press removes the state file"
pass "second press re-tiles exactly the windows it floated, then forgets them"

# --- restore skips windows that left or were re-tiled by hand ---------------

STATE="$TMP_ROOT/state-gone"
mkdir -p "$STATE"
printf '1\n3\n4\n' > "$STATE/editor"
d=$(new_case editor '1\tfloating\n4\th_tiles\n')
run "$d" "$STATE"
expect_code 0 $? "restore with gone windows"
calls=$(calls_of "$d")
assert_contains "$calls" "layout --window-id 1 tiling" "still-floating window 1 is re-tiled"
assert_not_contains "$calls" "layout --window-id 3" "window 3, no longer on the workspace, is skipped"
assert_not_contains "$calls" "layout --window-id 4" "window 4, already tiled again, is skipped"
assert_absent "$STATE/editor" "restore removes the state file"
pass "restore skips windows that closed, moved away or were already re-tiled"

# --- state is per workspace -------------------------------------------------

STATE="$TMP_ROOT/state-per-ws"
mkdir -p "$STATE"
printf '9\n' > "$STATE/comms"
d=$(new_case editor '5\th_tiles\n')
run "$d" "$STATE"
expect_code 0 $? "other workspace has state"
assert_contains "$(calls_of "$d")" "layout --window-id 5 floating" "editor floats although comms has state"
[ "$(cat "$STATE/comms")" = 9 ] || fail "comms state must be untouched"
pass "each workspace keeps its own toggle state"

# --- nothing to do ----------------------------------------------------------

STATE="$TMP_ROOT/state-empty"
d=$(new_case editor '2\tfloating\n')
run "$d" "$STATE"
expect_code 0 $? "no tiled windows"
assert_not_contains "$(calls_of "$d")" "layout --" "no tiled windows means no layout calls"
assert_absent "$STATE/editor" "no tiled windows means no state file"
pass "a workspace with nothing tiled and no state is a no-op"

# --- unusable workspace names fail closed -----------------------------------

for ws in "../escape" ".hidden" ""; do
  d=$(new_case "$ws" '1\th_tiles\n')
  run "$d" "$TMP_ROOT/state-bad"
  expect_code 1 $? "workspace '$ws'"
  assert_not_contains "$(calls_of "$d")" "layout --" "workspace '$ws' must not change any layout"
done
assert_absent "$TMP_ROOT/escape" "a ../ workspace name must not write outside the state dir"
pass "workspace names that aren't safe file names exit 1 without acting"
