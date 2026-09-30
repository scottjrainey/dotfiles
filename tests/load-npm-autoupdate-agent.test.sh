#!/usr/bin/env bash
# Behavior tests for scripts/load-npm-autoupdate-agent.sh and its rebuild.sh
# call site. Fakes launchctl, sudo, brew-free trust step and HOME so no live
# launchd or sudo is touched.
set -u

# shellcheck source=tests/lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

LOADER="$ROOT/scripts/load-npm-autoupdate-agent.sh"
[ -x "$LOADER" ] || fail "loader missing or not executable at $LOADER"

TMP_ROOT=$(fm_test_tmproot load-npm-autoupdate-agent) || fail "could not create a temp root"

# new_case <sudo-exit> <with-plist 0|1> <already-loaded 0|1>
new_case() {
  local dir fakebin
  dir=$(mktemp -d "$TMP_ROOT/case.XXXXXX") || return 1
  fakebin="$dir/fakebin"; mkdir -p "$fakebin" "$dir/home/Library/LaunchAgents"
  [ "$2" = 1 ] && : > "$dir/home/Library/LaunchAgents/com.scottjrainey.npm-global-autoupdate.plist"
  # bootstrap fails when already loaded, like the real thing; print succeeds then.
  cat > "$fakebin/launchctl" <<EOS
#!/usr/bin/env bash
echo "\$*" >> "$dir/launchctl.calls"
case "\$1" in
  bootstrap) [ -e "$dir/loaded" ] && exit 5; : > "$dir/loaded"; exit 0 ;;
  print) [ -e "$dir/loaded" ] && exit 0; exit 113 ;;
  *) exit 99 ;;
esac
EOS
  cat > "$fakebin/sudo" <<EOS
#!/usr/bin/env bash
echo "sudo \$*" >> "$dir/order.log"
exit $1
EOS
  [ "$3" = 1 ] && : > "$dir/loaded"
  chmod +x "$fakebin"/*
  echo "$dir"
}

run_loader() { HOME="$1/home" PATH="$1/fakebin:$PATH" "$LOADER"; }

# loads an unloaded agent, bootstrap only (never kickstart)
d=$(new_case 0 1 0)
run_loader "$d" >/dev/null || fail "loader exited nonzero"
grep -q '^bootstrap gui/[0-9]* .*npm-global-autoupdate.plist$' "$d/launchctl.calls" || fail "did not bootstrap the plist"
! grep -q kickstart "$d/launchctl.calls" || fail "loader kickstarted"
pass "loads an unloaded agent without kickstart"

# second run is a quiet no-op
out=$(run_loader "$d" 2>&1) || fail "second run exited nonzero"
[ -z "$out" ] || fail "second run was noisy: $out"
pass "idempotent when already loaded"

# missing plist skips without calling launchctl
d=$(new_case 0 0 0)
run_loader "$d" >/dev/null || fail "missing-plist run exited nonzero"
[ ! -e "$d/launchctl.calls" ] || fail "launchctl called without a plist"
pass "skips when plist absent"

# rebuild.sh: loader runs after the switch, and status is preserved.
# Copy the repo scripts into a sandbox so rebuild.sh's symlinks and cd stay local.
new_rebuild() { # <sudo-exit>
  local d; d=$(new_case "$1" 1 0)
  mkdir -p "$d/repo/scripts"
  cp "$ROOT/rebuild.sh" "$d/repo/"
  cp "$LOADER" "$d/repo/scripts/"
  printf '#!/usr/bin/env bash\nexit 0\n' > "$d/repo/scripts/trust-homebrew-taps.sh"
  chmod +x "$d/repo/scripts/"* "$d/repo/rebuild.sh"
  echo "$d"
}
run_rebuild() { ( HOME="$1/home" PATH="$1/fakebin:$PATH" "$1/repo/rebuild.sh" >/dev/null 2>&1 ); }

d=$(new_rebuild 0)
run_rebuild "$d" || fail "rebuild.sh failed on a good switch"
grep -q '^sudo darwin-rebuild switch' "$d/order.log" || fail "switch not run"
grep -q '^bootstrap ' "$d/launchctl.calls" || fail "rebuild did not load the agent"
run_rebuild "$d" || fail "second rebuild failed"
pass "rebuild.sh loads the agent after the switch, idempotently"

d=$(new_rebuild 7)
run_rebuild "$d"; rc=$?
[ "$rc" = 7 ] || fail "rebuild.sh did not preserve the switch status (got $rc)"
[ ! -e "$d/launchctl.calls" ] || fail "agent loaded after a failed switch"
pass "rebuild.sh preserves switch failure and skips the load"
