#!/usr/bin/env bash
# Claude Code status line — mirrors Starship config
# Receives JSON via stdin

input=$(cat)

cwd=$(echo "$input" | jq -r '.workspace.current_dir // .cwd // empty')
model=$(echo "$input" | jq -r '.model.display_name // empty')
used_pct=$(echo "$input" | jq -r '.context_window.used_percentage // empty')

# ANSI
RESET='\033[0m'

# Map context percentage to 256-color code (green→yellow→red gradient)
ctx_color() {
  local pct=$1
  if   ((pct <= 25)); then echo 46
  elif ((pct <= 27)); then echo 82
  elif ((pct <= 29)); then echo 118
  elif ((pct <= 31)); then echo 154
  elif ((pct <= 34)); then echo 190
  elif ((pct <= 37)); then echo 226
  elif ((pct <= 40)); then echo 220
  elif ((pct <= 43)); then echo 214
  elif ((pct <= 46)); then echo 208
  elif ((pct <= 49)); then echo 202
  else echo 196
  fi
}

# Directory — abbreviate $HOME to ~
if [ -n "$cwd" ]; then
  dir="${cwd/#$HOME/~}"
else
  dir="~"
fi

# Git branch and status (skip optional lock to avoid contention)
git_branch=""
git_dirty=""
if git -C "$cwd" rev-parse --git-dir >/dev/null 2>&1; then
  git_branch=$(git -C "$cwd" symbolic-ref --short HEAD 2>/dev/null \
               || git -C "$cwd" rev-parse --short HEAD 2>/dev/null)
  git_status=$(git -C "$cwd" status --porcelain 2>/dev/null)
  if [ -n "$git_status" ]; then
    git_dirty="*"
  fi
  # ahead/behind
  ahead=$(git -C "$cwd" rev-list --count @{u}..HEAD 2>/dev/null || echo "")
  behind=$(git -C "$cwd" rev-list --count HEAD..@{u} 2>/dev/null || echo "")
  git_sync=""
  if [ -n "$ahead" ] && [ "$ahead" -gt 0 ] 2>/dev/null; then
    git_sync="⇡${ahead}"
  fi
  if [ -n "$behind" ] && [ "$behind" -gt 0 ] 2>/dev/null; then
    git_sync="${git_sync}⇣${behind}"
  fi
fi

# Context usage with stepped gradient color (green→yellow→red)
ctx_info=""
if [ -n "$used_pct" ]; then
  printf -v used_int "%.0f" "$used_pct" 2>/dev/null || used_int="$used_pct"
  color="\033[38;5;$(ctx_color "$used_int")m"
  ctx_info="${color}${used_int}%${RESET}"
fi

# Build output — horizontal, pipe-separated
# Leading | prevents ~ from being first character (avoids rendering issues)
output="| $dir"

if [ -n "$git_branch" ]; then
  output="$output | $git_branch"
  if [ -n "$git_dirty" ] || [ -n "$git_sync" ]; then
    output="$output ($git_dirty$git_sync)"
  fi
fi

if [ -n "$model" ]; then
  output="$output | $model"
fi

if [ -n "$ctx_info" ]; then
  output="$output | $ctx_info"
fi

printf "%b\n" "$output"
