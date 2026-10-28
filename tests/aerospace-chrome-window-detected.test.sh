#!/usr/bin/env bash
# Behavior tests for aerospace-chrome-window-detected.
#
# Fakes aerospace, the osascript window-width probe and sleep on PATH
# (tests/aerospace-fakes.sh), so neither AeroSpace nor Chrome is needed.
set -u

# shellcheck source=tests/lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
# shellcheck source=tests/aerospace-fakes.sh
. "$(dirname "${BASH_SOURCE[0]}")/aerospace-fakes.sh"

SCRIPT="$FM_BIN_DIR/aerospace-chrome-window-detected"
[ -x "$SCRIPT" ] || fail "aerospace-chrome-window-detected is missing or not executable at $SCRIPT"

TMP_ROOT=$(fm_test_tmproot aerospace-chrome-detected) || fail "could not create a temp root"

run() { # <case-dir> <window-id> <args...>
  local dir=$1 id=$2
  shift 2
  AEROSPACE_WINDOW_ID="$id" TITLE_TRIES=5 PATH="$dir/fakebin:$PATH" "$SCRIPT" "$@" > "$dir/out" 2>&1
}

new_case() { # <width> [<list-windows output>]
  local d
  d=$(aerospace_case "$TMP_ROOT")
  printf '%s' "$1" > "$d/width"
  [ $# -lt 2 ] || printf '%b' "$2" > "$d/list-windows"
  printf '%s\n' "$d"
}

MOVE="move-node-to-workspace --window-id 42 browser"

# --- arguments fail closed --------------------------------------------------

d=$(new_case 1200)
run "$d" 42 --help
expect_code 0 $? "--help"
assert_contains "$(cat "$d/out")" "Usage: aerospace-chrome-window-detected" "--help prints usage"
for args in "" "bogus" "float-if-small extra"; do
  # shellcheck disable=SC2086 # word-splitting the arg sets is the point
  run "$d" 42 $args
  expect_code 2 $? "args '$args'"
done
for id in "" "12a" "-1"; do
  run "$d" "$id" float-if-small
  expect_code 2 $? "window id '$id'"
done
[ ! -s "$d/calls" ] || fail "argument errors must not call aerospace"
pass "bad arguments and a missing or non-numeric AEROSPACE_WINDOW_ID exit 2 without acting"

# --- float-if-small ---------------------------------------------------------

d=$(new_case 600)
run "$d" 42 float-if-small
expect_code 0 $? "small window"
assert_contains "$(calls_of "$d")" "layout --window-id 42 floating" "a 600pt window floats"
pass "float-if-small floats a window narrower than 1000pt"

d=$(new_case 1000)
run "$d" 42 float-if-small
expect_code 0 $? "1000pt window"
[ ! -s "$d/calls" ] || fail "a 1000pt window must stay tiled"
d=$(new_case "")
run "$d" 42 float-if-small
expect_code 0 $? "unknown window"
[ ! -s "$d/calls" ] || fail "a window CoreGraphics doesn't know must be left alone"
pass "float-if-small leaves windows at the threshold, or already gone, alone"

# --- route-cold-launch ------------------------------------------------------

d=$(new_case 1200 '42\tNew Tab\n')
run "$d" 42 route-cold-launch
expect_code 0 $? "cold launch"
calls=$(calls_of "$d")
assert_contains "$calls" "list-windows --monitor all --app-bundle-id com.google.Chrome --format %{window-id}%{tab}%{window-title}" "lists Chrome windows"
assert_contains "$calls" "$MOVE" "the only window, titled New Tab, goes to browser"
pass "route-cold-launch moves Chrome's only New Tab window to browser"

for listing in '42\tNew Tab\n7\tInbox\n' '42\tExample Domain\n' '7\tNew Tab\n'; do
  d=$(new_case 1200 "$listing")
  run "$d" 42 route-cold-launch
  expect_code 0 $? "listing $listing"
  assert_not_contains "$(calls_of "$d")" "move-node-to-workspace" "listing $listing must not route"
done
pass "a second Chrome window, a real page title or another window's id is not a cold launch"

d=$(new_case 600 '42\tNew Tab\n')
run "$d" 42 route-cold-launch
expect_code 0 $? "small New Tab"
assert_not_contains "$(calls_of "$d")" "move-node-to-workspace" "a popup-sized New Tab must not route"
pass "a popup-sized New Tab window is not routed"

d=$(new_case 1200 '42\t\n')
printf '42\tNew Tab\n' > "$d/list-windows.3"
run "$d" 42 route-cold-launch
expect_code 0 $? "late title"
calls=$(calls_of "$d")
assert_contains "$calls" "$MOVE" "a title that arrives late still routes"
[ "$(grep -c '^list-windows' "$d/calls")" -eq 3 ] || fail "late title: expected 3 list-windows calls"
pass "an empty title is re-read until it arrives"

d=$(new_case 1200 '42\t\n')
run "$d" 42 route-cold-launch
expect_code 0 $? "title never arrives"
assert_not_contains "$(calls_of "$d")" "move-node-to-workspace" "no title means no route"
[ "$(grep -c '^list-windows' "$d/calls")" -eq 5 ] || fail "never-titled: expected TITLE_TRIES=5 list-windows calls"
pass "a title that never arrives gives up after TITLE_TRIES reads"

d=$(new_case 1200 '42\tNew Tab\n')
echo 1 > "$d/list-windows.rc"
run "$d" 42 route-cold-launch
expect_code 0 $? "list-windows fails"
assert_not_contains "$(calls_of "$d")" "move-node-to-workspace" "a failed listing must not route"
pass "a failing list-windows is a silent no-op"
