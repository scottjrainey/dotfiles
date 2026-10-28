#!/usr/bin/env bash
# Behavior tests for aerospace-chrome-detach-tab.
#
# Fakes aerospace, osascript and sleep on PATH (tests/aerospace-fakes.sh), so
# neither AeroSpace nor Chrome is needed and no real tab is touched.
set -u

# shellcheck source=tests/lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
# shellcheck source=tests/aerospace-fakes.sh
. "$(dirname "${BASH_SOURCE[0]}")/aerospace-fakes.sh"

SCRIPT="$FM_BIN_DIR/aerospace-chrome-detach-tab"
[ -x "$SCRIPT" ] || fail "aerospace-chrome-detach-tab is missing or not executable at $SCRIPT"

TMP_ROOT=$(fm_test_tmproot aerospace-chrome-detach) || fail "could not create a temp root"

run() { # <case-dir> <args...>
  local dir=$1
  shift
  PATH="$dir/fakebin:$PATH" "$SCRIPT" "$@" > "$dir/out" 2>&1
}

# --- arguments fail closed --------------------------------------------------

d=$(aerospace_case "$TMP_ROOT")
run "$d" --help
expect_code 0 $? "--help"
assert_contains "$(cat "$d/out")" "Usage: aerospace-chrome-detach-tab" "--help prints usage"
run "$d" --bogus
expect_code 2 $? "--bogus"
[ ! -s "$d/calls" ] || fail "--help/--bogus must not run osascript or aerospace"
pass "--help exits 0 and an unknown argument exits 2, neither acting"

# --- detach, then tile and focus the newest Chrome window -------------------

d=$(aerospace_case "$TMP_ROOT")
printf '7\n42\n13\n' > "$d/list-windows"
run "$d"
expect_code 0 $? "detach"
calls=$(calls_of "$d")
assert_contains "$calls" 'close active tab of front window' "the AppleScript closes the active tab"
assert_contains "$calls" 'set newWin to make new window' "the AppleScript opens the tab in a new window"
assert_contains "$calls" "list-windows --monitor all --app-bundle-id com.google.Chrome --format %{window-id}" "lists Chrome windows"
assert_contains "$calls" "layout --window-id 42 tiling" "the newest (highest id) window is tiled"
assert_contains "$calls" "focus --window-id 42" "the newest window is focused"
[ "$(tail -n 1 "$d/calls")" = "focus --window-id 42" ] || fail "focus must come last, after tiling"
pass "detach tiles and focuses the highest-id Chrome window"

# --- failures ---------------------------------------------------------------

d=$(aerospace_case "$TMP_ROOT")
echo 1 > "$d/osascript.rc"
printf '42\n' > "$d/list-windows"
if run "$d"; then fail "a failing AppleScript must fail the script"; fi
assert_not_contains "$(calls_of "$d")" "layout --" "a failing AppleScript must not touch layouts"
pass "a failing AppleScript (Chrome not running) stops before any aerospace call"

d=$(aerospace_case "$TMP_ROOT")
run "$d"
expect_code 0 $? "no Chrome windows"
assert_not_contains "$(calls_of "$d")" "layout --" "no Chrome window means nothing to tile"
assert_not_contains "$(calls_of "$d")" "focus --" "no Chrome window means nothing to focus"
pass "no Chrome window left to find is a silent no-op"
