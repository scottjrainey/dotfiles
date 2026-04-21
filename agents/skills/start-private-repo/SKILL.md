---
name: start-private-repo
description: Initialize a fresh local git repository in a given directory and publish it as a new private GitHub repo via gh CLI. Use when the user wants to start a private repo, detach a directory from its existing git history and push as private, or fork-then-privatize a cloned project.
argument-hint: <directory> [repo-name]
arguments:
  - name: directory
    description: Path to the directory to publish as a new private repo
    required: true
  - name: repo-name
    description: Name for the new GitHub repo (defaults to directory name)
    required: false
---

# start-private-repo

Turn a local directory into a brand-new private GitHub repository, discarding any prior git history.

## Inputs

- **directory** (required): path to the directory to publish. If omitted, ask the user.
- **repo name** (optional): defaults to the directory name; `gh repo create` will prompt.

## Prerequisites

- `gh` CLI installed and authenticated (`gh auth status`). If not authenticated, run `gh auth login` and stop — let the user complete the interactive flow.

## Workflow

Run from inside the target directory. Confirm with the user before deleting `.git` if the directory has uncommitted work or unpushed commits.

```bash
cd <directory>
rm -rf .git
git init -b main
git add .
git commit -m "initial"
gh repo create --private --source=. --remote=origin --push
```

`gh repo create --push` handles the upstream push in one step. If it fails (e.g. name conflict), fall back to:

```bash
gh repo create --private --source=. --remote=origin
git push --set-upstream origin main
```

## Verify

- `gh repo view --web` to open the new repo
- Confirm visibility is **Private** and files are present

## Notes

- Destructive: `rm -rf .git` permanently severs history. Always confirm if the directory wasn't a throwaway copy.
- If the user wants to preserve the original repo, `cp -r <orig> <orig>-fork` first, then run this workflow in the copy.
