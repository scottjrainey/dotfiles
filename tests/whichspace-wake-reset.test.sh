#!/usr/bin/env bash
# Behavior tests for whichspace-wake-reset.sh.
#
# Fakes pgrep, sleep and launchctl on PATH so these run without a real
# WhichSpace process or a real wake - see docs/whichspace-wake-reset.md for
# how to verify the real fix end to end.
set -u

# shellcheck source=tests/lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

SCRIPT="$FM_BIN_DIR/whichspace-wake-reset.sh"
[ -x "$SCRIPT" ] || fail "whichspace-wake-reset.sh is missing or not executable at $SCRIPT"

TMP_ROOT=$(fm_test_tmproot whichspace-wake-reset) || fail "could not create a temp root"

# new_case <pgrep-exit> echoes a case dir with fakebin/{pgrep,sleep,launchctl}
# on it. pgrep exits with the given code (0 = "WhichSpace is running").
# sleep is a no-op so the test doesn't pay the script's real settle delay.
# launchctl appends its full argv, one per line, to launchctl.calls so a test
# can assert whether - and how - it was invoked.
new_case() { # <pgrep-exit>
  local dir fakebin
  dir=$(mktemp -d "$TMP_ROOT/case.XXXXXX") || return 1
  fakebin=$(fm_fakebin "$dir")

  cat > "$fakebin/pgrep" <<EOF
#!/usr/bin/env bash
exit $1
EOF
  chmod +x "$fakebin/pgrep"

  cat > "$fakebin/sleep" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
  chmod +x "$fakebin/sleep"

  cat > "$fakebin/launchctl" <<EOF
#!/usr/bin/env bash
printf '%s\n' "\$*" >> "$dir/launchctl.calls"
exit 0
EOF
  chmod +x "$fakebin/launchctl"

  printf '%s\n' "$dir"
}

# --- WhichSpace not running: no-op, launchctl never called -----------------

dir=$(new_case 1)
PATH="$dir/fakebin:$PATH" "$SCRIPT"
code=$?
expect_code 0 "$code" "not-running case exits 0"
assert_absent "$dir/launchctl.calls" "not-running case must not invoke launchctl"
pass "whichspace-wake-reset.sh is a no-op when WhichSpace isn't running"

# --- WhichSpace running: kickstarts the WhichSpace LaunchAgent -------------

dir=$(new_case 0)
PATH="$dir/fakebin:$PATH" "$SCRIPT"
code=$?
expect_code 0 "$code" "running case exits 0"
assert_present "$dir/launchctl.calls" "running case must invoke launchctl"
calls=$(cat "$dir/launchctl.calls")
assert_contains "$calls" "kickstart -k gui/" "must kickstart the gui/<uid> job"
assert_contains "$calls" "/io.gechr.WhichSpace" "must target WhichSpace's LaunchAgent label"
pass "whichspace-wake-reset.sh kickstarts WhichSpace when it's running"

exit 0
