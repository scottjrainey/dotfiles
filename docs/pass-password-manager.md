# pass

Operator notes for [`pass`](https://www.passwordstore.org/), the standard Unix password manager, and the GPG stack this repo installs underneath it.

Nothing here initializes a store or touches key material. That is a deliberate boundary: `pass init` binds a store to a specific GPG key, so it is the operator's own act, done by hand once, and is described but never automated.

## Status: installed, not initialized

`./rebuild.sh` installs the three formulae and links `~/.gnupg/gpg-agent.conf`. It does **not** create a GPG key and does **not** create `~/.password-store`. Until both of those exist, every `pass` subcommand except `pass --help`/`pass version` will fail. Walk "First-time setup" below once, by hand.

## Never commit the password store

`~/.password-store` must never be added to this repo, or to any repo, and `dotfiles` in particular is a **public** GitHub repo.

Encryption at rest is not a reason to publish it. A `.gpg` file is only as strong as the passphrase on the private key that opens it, and unlike a live decryption attempt a published copy can be attacked offline, forever, with no rate limit and no chance to rotate ahead of it. Publishing also leaks the store's plaintext structure regardless of the crypto: `pass` uses one file per entry and the *filenames are not encrypted*, so the directory tree alone discloses every service, account, and username being stored. Git history makes it permanent - a store committed once and deleted in the next commit is still fully retrievable from the repo's history and from every clone and fork.

If a private password store ever needs versioning, `pass git` puts it in its own separate private repository, which is what that subcommand exists for. It never belongs here.

The only `~/.gnupg` file this repo tracks is `home/.gnupg/gpg-agent.conf`, which holds no secret. `home.nix` links that single file rather than the directory, and `.gitignore` denies everything else under `home/.gnupg/`, because the same directory is where GPG keeps the private keyring.

## What gets installed

Three homebrew-core formulae, declared in `configuration.nix` and mirrored in `Brewfile`:

- `pass` - the password manager itself. It is a Bash script, not a crypto implementation.
- `gnupg` - provides `gpg` and `gpg-agent`. This is a hard dependency of the `pass` formula, so Homebrew installs it either way; it is declared anyway, because `gpg` is a tool the operator drives directly (key generation, key listing) rather than invisible plumbing.
- `pinentry-mac` - the native macOS passphrase dialog. **Not** a dependency of anything above; it is an explicit choice, for the reason in the next section.

All three are plain (non-tap-qualified) homebrew-core formulae, so none of them needs a `homebrew.taps` entry and none is touched by `bootstrap.sh` Step 8's `brew trust` parse.

Homebrew, not Nix, on purpose. `pass` was requested as a Homebrew formula, and its formula hard-depends on Homebrew's `gnupg` - so a `pkgs.gnupg` from `home.nix` would be a *second*, differently-configured GPG installation racing the first for `~/.gnupg` and for `gpg` on `PATH`, not a replacement for it. One GPG is the whole point.

## Why pinentry-mac

`gpg` never reads a passphrase itself. It hands the request to `gpg-agent`, which execs a separate helper - a *pinentry* - to do the prompting and hand the passphrase back.

Homebrew's `gnupg` depends only on the plain `pinentry` formula, which is the curses/tty variant. It prompts by drawing on a controlling terminal, so with no configuration at all `pass show` works from an interactive shell and fails everywhere else: from an editor, from a GUI app, from a launchd job, from an agent session. The failure surfaces as `gpg: public key decryption failed: Inappropriate ioctl for device` or `Screen or window too small`, neither of which points at the real cause.

`pinentry-mac` puts up a real macOS window instead, so any caller can prompt regardless of whether it owns a terminal. It is what the ecosystem standardizes on for exactly this situation, and upstream's own caveat gives the same one-line config this repo writes.

Two behaviors worth knowing before the first prompt:

- The dialog has a **"Save in Keychain"** checkbox. Ticking it stores the GPG passphrase in the macOS login keychain, and thereafter anything that can run as this user unlocks the store with no prompt at all. That is a real convenience/exposure trade; leave it unticked unless that is the intent.
- `pinentry-mac` needs a GUI session. Over a plain SSH login with no window server there is nothing to draw into and the prompt fails. Run `export GPG_TTY=$(tty)` and temporarily point `pinentry-program` at `/opt/homebrew/bin/pinentry-tty` (built by the same `pinentry` formula) for that case.

## How the pinentry is wired

Declaratively, by the same mechanism as every other dotfile here: `home.nix` links `home/.gnupg/gpg-agent.conf` to `~/.gnupg/gpg-agent.conf` with `mkOutOfStoreSymlink`, and that file sets

    pinentry-program /opt/homebrew/bin/pinentry-mac

Edit the repo copy to tune it; the change is live immediately, with no rebuild, like the other edit-in-place files. `gpg-agent` only reads its config at startup, so after an edit run:

    gpgconf --reload gpg-agent

Useful knobs for that file, both off by default: `default-cache-ttl <seconds>` (how long the agent remembers a passphrase after use, default 600) and `max-cache-ttl <seconds>` (hard ceiling regardless of use, default 7200).

Four notes on the mechanism:

- There is no LaunchAgent for `gpg-agent`, unlike the other background jobs in `docs/`. `gpg` auto-spawns the agent on demand and it exits on its own; nothing needs to schedule it.
- Home Manager's `services.gpg-agent` module was considered and rejected. It would express the same `pinentry-program` line through `pinentry.package`, but it hardwires the agent to `config.programs.gpg.package` - a *nixpkgs* GnuPG - and on Darwin relocates the agent socket to `/private/var/run/org.nix-community.home.gpg-agent/`, away from the stock `~/.gnupg`. Against a Homebrew `gpg` that is the two-GPG problem above plus a socket mismatch. The plain symlinked config file gets the same declarative result with none of that.
- Home Manager refuses to link over an existing unmanaged file. If `~/.gnupg/gpg-agent.conf` already exists as a real file when the next `./rebuild.sh` runs, activation fails with a "would be clobbered" error; move it aside and re-run.
- A rebuild also creates `~/.gnupg` itself, at mode 0700, ahead of that link - Home Manager's own link step would otherwise create it at 0755 and GnuPG would then warn about unsafe homedir permissions on every `gpg`/`pass` call. The mode is applied only when the directory is created, so an already-existing `~/.gnupg` is left exactly as it is; if it is already 0755, fix it once by hand with `chmod 700 ~/.gnupg`. The why is on `home.activation.gnupgHomedir` in `home.nix`.

## First-time setup

One-time, by hand, after a `./rebuild.sh` has installed the formulae.

1. Create a GPG key if there is not already one to use. `--full-generate-key` prompts for algorithm, expiry, identity, and the passphrase that will protect everything in the store:

       gpg --full-generate-key

   Pick a passphrase that is strong enough to stand alone. It is the only thing between an attacker holding a copy of the store and its plaintext.

2. Find the key's ID:

       gpg --list-secret-keys --keyid-format=long

3. Initialize the store against that key. This creates `~/.password-store`:

       pass init <key-id-or-email>

4. Back up the private key and generate a revocation certificate, and store both somewhere other than this machine. A lost private key means every entry in the store is permanently unreadable - `pass` has no recovery path.

## Daily use

    pass insert some/service          # add an entry, prompts for the value
    pass generate some/service 32     # generate and store a 32-char password
    pass show some/service            # print it (triggers the pinentry prompt)
    pass -c some/service              # copy to the clipboard, cleared after 45s
    pass ls                           # tree of the store
    pass rm some/service

The store lives at `~/.password-store` by convention; `PASSWORD_STORE_DIR` overrides it. Each entry is one GPG-encrypted file at the path matching its name - which is why the *names* are not secret even though the contents are.

## Verifying a change to this setup

    nix flake check --no-build --impure

That covers the `configuration.nix`/`home.nix` change. There is no test suite here: `pass` and `gnupg` are upstream packages, and the only repo-authored artifact is the one-line `gpg-agent.conf`.

After a rebuild, confirm the wiring end to end without touching a real store:

    which pass gpg pinentry-mac                 # all three resolve under /opt/homebrew/bin
    readlink ~/.gnupg/gpg-agent.conf            # points into ~/.dotfiles/home/.gnupg/
    grep pinentry-program "$(gpgconf --list-dirs homedir)/gpg-agent.conf"  # the agent's effective homedir declares it
    gpg-connect-agent 'GET_PASSPHRASE --data cid errtext prompt desc' /bye  # and the agent really launches it

The last one is the end-to-end proof: the native macOS `pinentry-mac` dialog appears. That it appears at all is the answer - press Escape to dismiss it and the command reports a cancel error, so nothing is cached and no key or store is involved.
