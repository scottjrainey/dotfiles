#!/usr/bin/env bash
# Behavior tests for npm-global-autoupdate.sh.
#
# Fakes npm, pgrep and osascript on PATH and points the prefix and state dir at
# a temp root, so nothing real is updated - see docs/npm-global-autoupdate.md
# for how to run the real thing once by hand.
set -u

# shellcheck source=tests/lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

SCRIPT="$FM_BIN_DIR/npm-global-autoupdate.sh"
[ -x "$SCRIPT" ] || fail "npm-global-autoupdate.sh is missing or not executable at $SCRIPT"

TMP_ROOT=$(fm_test_tmproot npm-global-autoupdate) || fail "could not create a temp root"

# new_case <pgrep-exit> <update-exit> <outdated-exit>
# Builds a prefix with one tool, "gh-axi", that offers `setup hooks` and logs
# each call, plus a tool, "plain", that does not. The fake npm lists gh-axi at
# 1.0.0 until `npm update` has run, then at 2.0.0.
new_case() {
  local dir fakebin prefix
  dir=$(mktemp -d "$TMP_ROOT/case.XXXXXX") || return 1
  fakebin=$(fm_fakebin "$dir")
  prefix="$dir/prefix"
  mkdir -p "$prefix/bin" "$dir/state"

  cat > "$prefix/bin/gh-axi" <<EOF
#!/usr/bin/env bash
if [ "\$1 \$2" = "setup --help" ]; then echo "usage: gh-axi setup hooks"; exit 0; fi
if [ "\$1 \$2" = "setup hooks" ]; then echo gh-axi >> "$dir/setup.calls"; exit 0; fi
exit 0
EOF
  cat > "$prefix/bin/plain" <<'EOF'
#!/usr/bin/env bash
echo "plain help with no setup subcommand"
echo plain >> "${PLAIN_CALLS:-/dev/null}"
EOF
  chmod +x "$prefix/bin/gh-axi" "$prefix/bin/plain"

  cat > "$fakebin/pgrep" <<EOF
#!/usr/bin/env bash
exit $1
EOF
  cat > "$fakebin/npm" <<EOF
#!/usr/bin/env bash
case "\$1" in
  view) if [ "\$2" = "unpublished" ]; then echo "npm error code E404" >&2; exit 1; fi
        [ -e "$dir/offline" ] && { echo "npm error code ENOTFOUND" >&2; exit 1; }
        exit 0 ;;
  update) case "\$*" in *unpublished*) echo "unpublished must not be updated" >&2; exit 9 ;; esac
          touch "$dir/updated"; exit $2 ;;
  outdated) exit $3 ;;
  ls)
    [ -e "$dir/lsfail" ] && { echo "npm error broken tree" >&2; exit 1; }
    echo "$prefix/lib"
    echo "$prefix/lib/node_modules/unpublished:unpublished@0.1.0:"
    if [ -e "$dir/updated" ]; then echo "$prefix/lib/node_modules/gh-axi:gh-axi@2.0.0:"
    else echo "$prefix/lib/node_modules/gh-axi:gh-axi@1.0.0:"; fi
    ;;
esac
EOF
  cat > "$fakebin/osascript" <<EOF
#!/usr/bin/env bash
echo "\$*" >> "$dir/notify.calls"
EOF
  chmod +x "$fakebin/pgrep" "$fakebin/npm" "$fakebin/osascript"
  printf '%s\n' "$dir"
}

run() { # <dir>
  NPM_GLOBAL_PREFIX="$1/prefix" NPM_GLOBAL_AUTOUPDATE_STATE_DIR="$1/state" \
    NPM_GLOBAL_SETUP_PROBE_TIMEOUT=${PROBE_TIMEOUT:-5} PLAIN_CALLS="$1/plain.calls" \
    PATH="$1/fakebin:$PATH" "$SCRIPT" > "$1/out" 2>&1
}

# --- bad argument fails closed ----------------------------------------------

"$SCRIPT" --bogus > /dev/null 2>&1
expect_code 2 "$?" "unknown argument"
pass "rejects unknown arguments"

# --- successful update: runs setup hooks once, only where offered -----------

dir=$(new_case 1 0 0)
run "$dir"
expect_code 0 "$?" "update case"
assert_grep "gh-axi" "$dir/setup.calls" "changed package must trigger setup hooks"
[ "$(wc -l < "$dir/setup.calls" | tr -d ' ')" = 1 ] || fail "setup hooks must run exactly once"
assert_contains "$(cat "$dir/state/status")" "ok " "status file records ok"
assert_present "$dir/state/last-ok" "success leaves the last-ok marker"
assert_absent "$dir/plain.calls" "tools outside the known list must never be executed"
assert_absent "$dir/notify.calls" "success must not notify"
assert_contains "$(cat "$dir/state/status")" "unmanaged (not in registry): unpublished" "unpublished package is named, not failed on"
pass "updates, then runs setup hooks for tools that offer them"

# --- second run with nothing changed: no setup hooks ------------------------

rm -f "$dir/setup.calls"
run "$dir"
expect_code 0 "$?" "no-op case"
assert_absent "$dir/setup.calls" "unchanged packages with a prior ok must not re-run setup"
assert_contains "$(cat "$dir/state/status")" "already current" "status says already current"
pass "skips setup hooks when nothing changed"

# --- npm update failure: loud -----------------------------------------------

dir=$(new_case 1 1 0)
run "$dir"
expect_code 1 "$?" "update failure"
assert_contains "$(cat "$dir/state/status")" "failed " "status file records failure"
assert_present "$dir/notify.calls" "failure must notify"
assert_absent "$dir/state/last-ok" "failure must not leave a last-ok marker"
pass "an npm update failure exits nonzero, records it and notifies"

# --- still outdated after update: loud --------------------------------------

dir=$(new_case 1 0 1)
run "$dir"
expect_code 1 "$?" "still-outdated"
assert_contains "$(cat "$dir/state/status")" "still outdated" "status names the outdated failure"
pass "packages still outdated after the update fail the run"

# --- live session: defer without touching anything --------------------------

dir=$(new_case 0 0 0)
run "$dir"
expect_code 0 "$?" "deferred"
assert_absent "$dir/updated" "deferral must not run npm update"
assert_contains "$(cat "$dir/state/status")" "deferred " "status records the deferral"
pass "defers while tools in the prefix are running"

# --- registry unreachable: loud, not mistaken for unpublished ---------------

dir=$(new_case 1 0 0)
touch "$dir/offline"
run "$dir"
expect_code 1 "$?" "registry unreachable"
assert_contains "$(cat "$dir/state/status")" "could not query the npm registry" "status names the registry failure"
pass "a non-404 registry failure fails the run"

# --- missing prefix: loud ---------------------------------------------------

dir=$(new_case 1 0 0)
rm -rf "$dir/prefix"
run "$dir"
expect_code 1 "$?" "missing prefix"
assert_contains "$(cat "$dir/state/status")" "does not exist" "status names the missing prefix"
pass "a missing prefix fails the run"

# --- failure after a prior success clears last-ok, so setup re-runs ---------

dir=$(new_case 1 1 0)
touch "$dir/state/last-ok"
run "$dir"
expect_code 1 "$?" "failure after prior ok"
assert_absent "$dir/state/last-ok" "a failed run must clear last-ok"
pass "a failed run clears last-ok"

dir=$(new_case 1 0 0)
touch "$dir/state/last-ok" "$dir/lsfail"
run "$dir"
expect_code 1 "$?" "npm ls failure"
assert_contains "$(cat "$dir/state/status")" "could not list installed packages" "status names the npm ls failure"
assert_absent "$dir/updated" "a broken npm ls must not fall through to an update"
assert_absent "$dir/state/last-ok" "npm ls failure clears last-ok"
pass "a broken npm ls fails the run"

dir=$(new_case 1 0 0)
run "$dir"
rm -f "$dir/setup.calls" "$dir/state/last-ok"
run "$dir"
expect_code 0 "$?" "rerun without last-ok"
assert_grep "gh-axi" "$dir/setup.calls" "a run without last-ok must re-run setup even when nothing changed"
pass "missing last-ok re-runs setup hooks"

# --- repeated deferral escalates to a visible failure -----------------------

dir=$(new_case 0 0 0)
run "$dir"
expect_code 0 "$?" "first deferral"
run "$dir"
expect_code 0 "$?" "second deferral"
assert_absent "$dir/notify.calls" "deferrals below the limit stay quiet"
run "$dir"
expect_code 1 "$?" "third deferral"
assert_contains "$(cat "$dir/state/status")" "failed " "status records the escalation"
assert_contains "$(cat "$dir/state/status")" "deferred 3 runs in a row" "status names the stuck deferral"
assert_present "$dir/notify.calls" "escalated deferral must notify"
assert_absent "$dir/updated" "escalation must not update"
printf '#!/usr/bin/env bash\nexit 1\n' > "$dir/fakebin/pgrep"
run "$dir"
expect_code 0 "$?" "idle run after deferrals"
assert_absent "$dir/state/deferrals" "a non-deferred run resets the deferral count"
pass "consecutive deferrals escalate to a failure and reset on a real run"

# --- stale lock is taken over; fresh lock defers ----------------------------

dir=$(new_case 1 0 0)
mkdir "$dir/state/lock"
run "$dir"
expect_code 0 "$?" "fresh lock"
assert_contains "$(cat "$dir/state/status")" "deferred " "fresh lock defers"
assert_absent "$dir/updated" "fresh lock must not update"
touch -t 200001010000 "$dir/state/lock"
run "$dir"
expect_code 0 "$?" "stale lock"
assert_contains "$(cat "$dir/state/status")" "ok " "stale lock is taken over"
assert_present "$dir/updated" "stale lock run must update"
pass "a stale lock is removed, a fresh one defers"

# --- setup probe is bounded -------------------------------------------------

dir=$(new_case 1 0 0)
printf '#!/usr/bin/env bash\nsleep 30\n' > "$dir/prefix/bin/pi"
chmod +x "$dir/prefix/bin/pi"
start=$(date +%s)
PROBE_TIMEOUT=1 run "$dir"
expect_code 0 "$?" "hanging probe"
[ $(($(date +%s) - start)) -lt 20 ] || fail "a hanging setup probe must be killed at the timeout"
assert_grep "gh-axi" "$dir/setup.calls" "other tools still get setup hooks after a probe times out"
pass "a hanging setup probe is bounded"

exit 0
