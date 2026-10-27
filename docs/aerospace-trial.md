# AeroSpace trial

Operator notes for running [AeroSpace](https://github.com/nikitabobko/AeroSpace) alongside yabai/skhd on macOS 26, with yabai/skhd kept intact as the one-step rollback.

## Why

yabai's scripting addition does not load on macOS 27, so the six labelled Spaces and every `space --focus` / `window --space` binding break there.
AeroSpace needs no scripting addition, no SIP change, no sudoers entry and no Dock injection, so it is the candidate replacement.
This trial runs it on macOS 26 first, where switching back to yabai is still cheap.
The macOS 27 upgrade itself stays on hold.

## What this repo sets up

- `configuration.nix` / `Brewfile`: the `nikitabobko/tap` tap and its `nikitabobko/tap/aerospace` cask (AeroSpace 0.21.3-Beta at the time of writing).
- `flake.nix`: `nix-homebrew` pinned to the commit that ships Homebrew 6.0.22. The cask uses the `postflight_steps do run ... end` DSL, which needs Homebrew 6.0.16 or newer; the previous lock held Homebrew at 6.0.12, and that is what made `brew bundle` fail on the cask in September (not a broken cask upstream).
- `home/.config/aerospace/aerospace.toml`, linked to `~/.config/aerospace/aerospace.toml`.
- Helper scripts in `home/.local/bin/`, each with a `tests/<name>.test.sh`:
  - `aerospace-stack-focus`: alt+ctrl+j/k stack cycling.
  - `aerospace-workspace-float-toggle`: service-mode `f`.
  - `aerospace-chrome-window-detected`: Chrome popup floating and cold-launch routing.
  - `aerospace-chrome-detach-tab`: alt+shift+o.

`start-at-login = false`, so a rebuild installs AeroSpace but nothing starts it.
yabai, skhd, `.yabairc`, `.skhdrc`, WhichSpace and the sleepwatcher agent are untouched and keep running as before.

## Try it

1. Rebuild (`./rebuild.sh`), then check that Homebrew is new enough and AeroSpace is installed:

   ```sh
   brew --version                        # 6.0.22
   ls -d /Applications/AeroSpace.app
   ```

2. Optional snapshot of the yabai state, for comparison later:

   ```sh
   mkdir -p ~/aerospace-trial
   yabai -m query --spaces  > ~/aerospace-trial/spaces.json
   yabai -m query --windows > ~/aerospace-trial/windows.json
   ```

3. Gather every window onto Desktop 1 while yabai still runs. AeroSpace is meant to run on a single native Space. Don't delete the other five Spaces; yabai needs them for a rollback.

   ```sh
   for id in $(yabai -m query --windows | jq '.[] | select(.space != 1) | .id'); do yabai -m window "$id" --space 1; done
   yabai -m space --focus 1
   ```

4. Stop skhd and yabai. Both grab the same alt chords as AeroSpace, so they must not run at the same time.

   ```sh
   skhd --stop-service; yabai --stop-service
   ```

5. Start AeroSpace and grant Accessibility when asked (System Settings > Privacy & Security > Accessibility):

   ```sh
   open -a AeroSpace
   ```

   Windows that are already open when AeroSpace starts get their float/tile rule but are not routed (that is the startup grace below), so spread them once with `alt+shift+<key>`.

6. Optional, AeroSpace-recommended tweaks, each undone with `defaults delete` plus the same `killall`:

   ```sh
   defaults write com.apple.dock expose-group-apps -bool true && killall Dock   # readable Mission Control
   defaults write -g NSWindowShouldDragOnGesture -bool true                     # ctrl+cmd+drag moves any window
   ```

Things worth checking during the trial:

- alt+1..6 and alt+letter, many times at normal speed: does the switch ever flash through another workspace?
- `alt+shift+<key>` moves the window and follows it.
- Routing for each tiled app; Chrome cold launch vs `open https://...` from Ghostty vs a Google sign-in popup vs Cmd+N; alt+shift+o.
- Stacks: `alt+ctrl+shift+<dir>` to make one, alt+ctrl+j/k to cycle (does it wrap inside the stack?), service-mode `alt+shift+<dir>` to pull a window out.
- Service mode: each binding drops back out on its own.
- Lid-close sleep and wake: do windows stay on their workspaces?
- Login with session restore, and battery / WindowServer CPU against a typical yabai day.

While tuning `aerospace.toml`, service-mode `esc` reloads it.

## Roll back

Any time, about a minute:

```sh
osascript -e 'quit app "AeroSpace"'           # puts every window back on screen
yabai --start-service; skhd --start-service   # labels are still on the six Spaces
```

Windows stay wherever they are; re-file them with `alt+shift+<key>`.
Reverting the commit that added the trial removes the config and links, and the next rebuild uninstalls the cask (`onActivation.cleanup = "zap"`).
The nix-homebrew pin can stay either way: it is harmless without AeroSpace, and any other tap that adopts `postflight_steps` would break on Homebrew 6.0.12 the same way.

## Keybindings

Every chord in `.skhdrc` keeps the same key in `aerospace.toml`, except service-mode `s` (below).

| Chord | yabai/skhd | AeroSpace |
|---|---|---|
| alt+/ | rotate the space's bsp tree | `layout tiles horizontal vertical` |
| alt+, | whole-space stack layout | `layout accordion horizontal vertical` (focused container) |
| alt+shift+h/j/k/l | `window --swap` | `move` |
| alt+ctrl+j / k | `yabai-stack-focus next/prev` | `aerospace-stack-focus next/prev` |
| alt+ctrl+shift+h/j/k/l | `window --stack <dir>` | `join-with <dir>`, then `layout accordion` |
| alt+- / alt+= | edge resize -50 / +50 | `resize smart -50 / +50` |
| alt+1..6, alt+b/c/e/n/p/t | `space --focus <label>` | `workspace <name>` |
| alt+shift+1..6, alt+shift+b/c/e/n/p/t | `window --space` then `space --focus` | `move-node-to-workspace --focus-follows-window` |
| alt+shift+o | Chrome tab detach (inline) | `aerospace-chrome-detach-tab` |
| alt+shift+f | zoom-fullscreen | `fullscreen` |
| alt+shift+space | float/tile toggle | `layout floating tiling` |
| alt+tab | previous space | `workspace-back-and-forth` |
| alt+shift+tab | disabled | disabled |
| alt+h/j/k/l | unbound | unbound |
| alt+shift+; | enter service mode | `mode service` |
| service esc | leave | `reload-config`, leave |
| service r | `space --balance` | `balance-sizes` |
| service f | whole space bsp/float | `aerospace-workspace-float-toggle` |
| service s | relabel the six Spaces | not bound |
| service backspace | close all but current | `close-all-windows-but-current` |
| service h/j/k/l | focus | `focus` |
| service alt+shift+h/j/k/l | `window --warp` (also unstacks) | `join-with` (also unstacks) |
| service up / down / shift+down | volume +10 / -10 / mute via osascript | `volume up / down / mute-on` |

### Deviations

Same key, different behaviour:

1. **alt+/** flips the focused container between horizontal and vertical tiles, instead of rotating the whole bsp tree 90 degrees.
2. **alt+,** turns the focused container into an accordion, not the whole space. This is the gap `.skhdrc`'s own comment describes, now closed.
3. **alt+shift+h/j/k/l** uses `move`, not swap. Inside one container it swaps places with the neighbour, as before. At a container edge it moves the window into the neighbouring container or out of its own; that is also how a window joins an existing stack.
4. **alt+ctrl+j/k** has no "N of M" notification (AeroSpace has no position-in-container query); the 30px accordion edges of the other stack members are the cue instead. The wrap is AeroSpace's workspace-level `--wrap-around`, which lands back on the stack's first member when the stack spans the workspace along its axis, the shape join-with normally produces.
5. **alt+ctrl+shift+h/j/k/l** joins the focused window and its neighbour into a new accordion. If the neighbour is already a stack, the result nests rather than growing that stack; use `alt+shift+<dir>` to move a window into an existing stack.
6. **alt+- / alt+=** resize along the parent container's axis (true "smart" resize) instead of approximating with the right/left edge.
7. **service esc** also reloads `aerospace.toml` before leaving the mode.
8. **service r** evens out window sizes with `balance-sizes`. `flatten-workspace-tree` (the original AeroSpace binding) would also dissolve stacks, which `space --balance` never did.
9. **service f** floats every tiled window on the workspace and, on the next press, re-tiles exactly those windows. It is per window, since AeroSpace has no workspace-wide float layout; windows that were floating before stay floating, as with yabai.
10. **service s** is not bound. Workspace names live in `aerospace.toml`, so there are no Space labels to drift and nothing to repair.
11. **Service mode and unbound keys.** skhd's `@` swallowed every unbound key while in service mode. In AeroSpace an unbound key reaches the focused app and the mode stays on until a bound key (esc) is pressed.
12. **service alt+shift+h/j/k/l** uses `join-with` (the original AeroSpace binding), which builds a real container with the neighbour. Like `--warp`, from inside a stack it pulls the window out.
13. **service up/down** step the volume by 1/16 (6.25 points, the same step as the keyboard volume keys) instead of 10, and show AeroSpace's on-screen volume indicator.

### Other behaviour changes

- **Float by default, opt-in tiling.** Same app list as `.yabairc`, except Terminal.app, which stays floating (see losses).
- **App routing.** Same apps and workspaces. Windows found while AeroSpace starts up get their float/tile rule but are not routed; this replaces `.yabairc`'s 20-second startup grace. Windows that macOS session restore opens after that scan are still routed, so a login can move a few restored windows.
- **Chrome.** Windows narrower than 1000pt float, and a cold launch (one window, "New Tab") goes to `browser`, as in `.yabairc`. Both run as a script after the window appears, so a routed Chrome window can show briefly where it opened.
- **Workspaces** are AeroSpace's own, on one native Space. The menu-bar AeroSpace icon shows the focused workspace's name.
- **Mouse follows focus** via `move-mouse window-lazy-center`, as `mouse_follows_focus on`.
- **Gaps** match the yabai padding (24 top, 40 bottom, 30 sides) and the 3px window gap.

### Accepted losses

- **Terminal.app native tabs.** AeroSpace sees each tab as a window and has no equivalent of the `.yabairc` bsp-rebuild workaround, so Terminal.app floats. Ghostty is unaffected.
- **bsp auto-split.** New windows join the focused window's container (i3-style); split by hand with join-with.
- **fn+drag move and fn+right-drag resize.** AeroSpace has no modifier-drag. Dragging a tiled window's title bar re-inserts it at the drop point, dragging its edges resizes it, and the optional `NSWindowShouldDragOnGesture` default above gives ctrl+cmd+drag-anywhere.
- **"N of M" stack notification** (see deviation 4).
- **WhichSpace's lettered, coloured strip.** WhichSpace only understands native Spaces, so with one Space it shows a single badge. AeroSpace's menu-bar workspace name is the indicator for the trial. WhichSpace and its sleepwatcher wake fix stay installed for the yabai side.

## Adopting it later

Not part of this trial. When it passes: set `start-at-login = true`, `yabai --uninstall-service; skhd --uninstall-service`, keep both packages and their config for a few weeks of easy rollback, then reduce native Spaces to one and retire WhichSpace and the sleepwatcher agent. Re-enabling SIP and removing yabai/skhd come last, because rolling back after that needs recoveryOS.

## Verifying changes

```sh
shellcheck --norc --external-sources home/.local/bin/aerospace-*
for t in tests/aerospace-*.test.sh; do "$t"; done
nix flake check --no-build --impure
```

The tests fake `aerospace`, `osascript` and `sleep` on `PATH` (`tests/aerospace-fakes.sh`), so they need neither AeroSpace nor Chrome.
The config itself is easiest to check from a running AeroSpace with service-mode `esc` (or `aerospace reload-config`), which reports parse errors.

## History

AeroSpace ran on this machine before yabai. `home/.yabairc` and `home/.skhdrc` were translated from its config and keep comments crediting the AeroSpace bindings they came from; `aerospace.toml` here was rebuilt from those two files, so it follows today's yabai behaviour rather than the old config (the last version is at `git show 9f7eecc^:home/.config/aerospace/aerospace.toml`).
The cask was removed in `9f7eecc` because `brew bundle` started failing on it. The cause was the stale Homebrew pin described above, not a broken cask.
