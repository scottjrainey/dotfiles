---
allowed-tools: Bash(git add:*), Bash(git status:*), Bash(git commit:*)
description: Create a git commit
---

## Context

- Current git status: !`git status`
- Current git diff (staged and unstaged changes): !`git diff HEAD`
- Current branch: !`git branch --show-current`
- Recent commits: !`git log --oneline -10`

## Your task

First, check if the project has its own `/commit` command:
1. Look for a commit skill/command in .claude/, claude/, or .anthropic/ directories
2. Check if there's a `/commit` command defined in the project's claude configuration

If a project-specific `/commit` command exists:
- Use that command instead by calling the Skill tool with skill: "commit"
- Follow any project-specific commit conventions defined in that command

If no project-specific `/commit` command exists:
- Based on the above changes and recent commit history, create a single git commit
- Follow the repository's commit message style (see recent commits above)
- Use a single-line commit message in the format: `type: description`
- Common types: fix, feat, chore, refactor, docs
- Keep the message concise and descriptive
- Use present tense (e.g., "add", "fix", "update")
- Do not include Co-Authored-By or any additional lines
- You have the capability to call multiple tools in a single response
- Stage and create the commit with: `git commit -m "type: description"`
- Do not use any other tools or do anything else
- Do not send any other text or messages besides these tool calls
