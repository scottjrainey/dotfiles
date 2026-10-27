#!/usr/bin/env bash
# tests/aerospace-fakes.sh - fake aerospace/osascript/sleep for the AeroSpace
# helper-script tests (tests/aerospace-*.test.sh). Not a test itself.
#
# Source after tests/lib.sh:
#   # shellcheck source=tests/aerospace-fakes.sh
#   . "$(dirname "${BASH_SOURCE[0]}")/aerospace-fakes.sh"
#
# aerospace_case <tmp-root> echoes a fresh case dir whose fakebin/ holds:
#   aerospace   logs each call's argv as one line to <case>/calls, then
#               - list-workspaces: prints <case>/workspace
#               - list-windows:    prints <case>/list-windows.<n> for the n-th
#                                  list-windows call if that file exists, else
#                                  <case>/list-windows; exits with the number
#                                  in <case>/list-windows.rc if present
#               - anything else:   prints nothing, exits 0
#   osascript   `-l JavaScript` (the window-width probe) prints <case>/width;
#               anything else logs "osascript <argv>" to <case>/calls and
#               exits with the number in <case>/osascript.rc if present
#   sleep       no-op, so retry loops run instantly
# Run the script under test with PATH="<case>/fakebin:$PATH".

aerospace_case() {
  local dir fakebin
  dir=$(mktemp -d "$1/case.XXXXXX") || return 1
  fakebin=$(fm_fakebin "$dir")

  cat > "$fakebin/aerospace" <<EOF
#!/usr/bin/env bash
printf '%s\n' "\$*" >> "$dir/calls"
case "\$1" in
  list-workspaces) cat "$dir/workspace" ;;
  list-windows)
    n=\$(( \$(cat "$dir/list-windows.count" 2>/dev/null || echo 0) + 1 ))
    echo "\$n" > "$dir/list-windows.count"
    if [ -e "$dir/list-windows.\$n" ]; then cat "$dir/list-windows.\$n"
    elif [ -e "$dir/list-windows" ]; then cat "$dir/list-windows"; fi
    exit "\$(cat "$dir/list-windows.rc" 2>/dev/null || echo 0)"
    ;;
esac
exit 0
EOF
  cat > "$fakebin/osascript" <<EOF
#!/usr/bin/env bash
if [ "\$1 \$2" = "-l JavaScript" ]; then
  cat "$dir/width" 2>/dev/null
  exit 0
fi
printf 'osascript %s\n' "\$*" >> "$dir/calls"
exit "\$(cat "$dir/osascript.rc" 2>/dev/null || echo 0)"
EOF
  cat > "$fakebin/sleep" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
  chmod +x "$fakebin/aerospace" "$fakebin/osascript" "$fakebin/sleep"
  : > "$dir/calls"
  printf '%s\n' "$dir"
}

# calls_of <case-dir>: the logged calls, one per line.
calls_of() {
  cat "$1/calls"
}
