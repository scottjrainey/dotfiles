# Sync Docs

Synchronize project documentation with the current state of the codebase.

## Run

1. Check for `.claude/commands/sync-docs.md` in the project root - if found, follow that instead
2. Otherwise, recursively find all `README.md`, `AGENTS.md`, and `CLAUDE.md` files in the repository
3. Use `git ls-files` to understand the current project structure
4. Read each documentation file and assess if it needs updates based on:
   - Files that exist vs files mentioned in docs
   - Current project structure vs documented structure
   - Outdated information or missing sections
5. Update documentation files only if changes are needed
6. Summarize any updates made, or confirm that docs are already in sync
