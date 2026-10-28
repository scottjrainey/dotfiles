#!/usr/bin/env bash
# Behavior tests for aerospace-stack-focus.
#
# Fakes the aerospace CLI on PATH (tests/aerospace-fakes.sh), so no AeroSpace
# needs to be installed or running.
set -u

# shellcheck source=tests/lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
# shellcheck source=tests/aerospace-fakes.sh
. "$(dirname "${BASH_SOURCE[0]}")/aerospace-fakes.sh"

SCRIPT="$FM_BIN_DIR/aerospace-stack-focus"
[ -x "$SCRIPT" ] || fail "aerospace-stack-focus is missing or not executable at $SCRIPT"

TMP_ROOT=$(fm_test_tmproot aerospace-stack-focus) || fail "could not create a temp root"

run() { # <case-dir> <args...>
  local dir=$1
  shift
  PATH="$dir/fakebin:$PATH" "$SCRIPT" "$@" > "$dir/out" 2>&1
}

# --- arguments fail closed --------------------------------------------------

d=$(aerospace_case "$TMP_ROOT")
run "$d" --help
expect_code 0 $? "--help"
assert_contains "$(cat "$d/out")" "Usage: aerospace-stack-focus next|prev" "--help prints usage"
pass "--help prints usage and exits 0"

for args in "" "sideways" "next extra"; do
  d=$(aerospace_case "$TMP_ROOT")
  # shellcheck disable=SC2086 # word-splitting the arg sets is the point
  run "$d" $args
  expect_code 2 $? "args '$args'"
  [ ! -s "$d/calls" ] || fail "args '$args' must not call aerospace"
done
pass "missing, unknown or extra arguments exit 2 without calling aerospace"

# --- direction follows the accordion's axis ---------------------------------

check_direction() { # <layout> <verb> <expected-focus-call>
  local d
  d=$(aerospace_case "$TMP_ROOT")
  printf '%s\n' "$1" > "$d/list-windows"
  run "$d" "$2"
  expect_code 0 $? "$1 $2"
  assert_contains "$(calls_of "$d")" "list-windows --focused --format %{window-layout}" "$1 $2 queries the focused layout"
  assert_contains "$(calls_of "$d")" "$3" "$1 $2 focuses along the stack axis"
}

check_direction v_accordion next "focus --wrap-around down"
check_direction v_accordion prev "focus --wrap-around up"
check_direction h_accordion next "focus --wrap-around right"
check_direction h_accordion prev "focus --wrap-around left"
pass "v_accordion cycles down/up and h_accordion right/left, wrapping"

# --- not in a stack is a no-op ----------------------------------------------

for layout in h_tiles v_tiles floating; do
  d=$(aerospace_case "$TMP_ROOT")
  printf '%s\n' "$layout" > "$d/list-windows"
  run "$d" next
  expect_code 0 $? "$layout next"
  assert_not_contains "$(calls_of "$d")" "focus --" "$layout must not move focus"
done
pass "tiles and floating windows are a silent no-op"

d=$(aerospace_case "$TMP_ROOT")
echo 1 > "$d/list-windows.rc"
run "$d" next
expect_code 0 $? "no focused window"
assert_not_contains "$(calls_of "$d")" "focus --" "no focused window must not move focus"
pass "no focused window is a silent no-op"
