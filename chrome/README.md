# Chrome Extensions as Code

This is the personal dotfiles style: keep a plain JSON list of Chrome extension
IDs, generate a macOS configuration profile from it, and install/remove that
profile when bootstrapping or testing a machine.

The profile identifier is:

```text
engineer.scottjrainey.dotfiles.chrome
```

That identifier is the top-level `PayloadIdentifier` inside
`chrome.mobileconfig.template`. It is what macOS uses when listing or removing
the installed profile.

Snapshot the extensions from the default Chrome profile:

```sh
node scripts/snapshot-chrome-extensions.mjs > chrome/extensions.json
```

The snapshot script intentionally skips Chrome-managed component extensions and
extensions whose names include `password manager`, so the shared extension list
does not disclose security tooling.

Snapshot a different profile:

```sh
node scripts/snapshot-chrome-extensions.mjs "Profile 1" > chrome/extensions.json
```

Include Chrome-managed component extensions:

```sh
node scripts/snapshot-chrome-extensions.mjs --include-components > chrome/extensions.json
```

Generate the installable macOS configuration profile:

```sh
node scripts/generate-chrome-mobileconfig.mjs
```

Validate it:

```sh
plutil -lint chrome/chrome.mobileconfig
```

Install it:

```sh
sudo profiles install -type configuration -path chrome/chrome.mobileconfig
```

Confirm it in Chrome:

```text
chrome://policy
```

Click "Reload policies" and check for `ExtensionInstallForcelist`.

Remove the profile after testing:

```sh
sudo profiles remove -identifier engineer.scottjrainey.dotfiles.chrome
```

Chrome will show these extensions as managed because the profile controls the
`ExtensionInstallForcelist` policy.
