# Installing dotfiles

For those that care for such nonsense...

```sh
brew bundle --file=Brewfile
stow aerospace bat ghostty nvim starship tmux zsh
```

## Notes

### Aerospace

MacOS applies stricter privacy controls (TCC) to directories like ~/Documents, ~/Desktop, and ~/Downloads.

Apps—especially sandboxed ones, like Aerospace—must request explicit user permission to access these locations, even if the file path is valid and the file exists. When a config file is symlinked to somewhere inside `~/Documents`, macOS sees it as an access to a protected location and may deny access silently or log it.

Placing `dotfiles` in a less restricted path like `~/dotfiles`, avoids these privacy controls, and apps can freely follow the symlink without triggering System Policy denials.
