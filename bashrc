#!/bin/bash
# Use vi mode
set -o vi

# Aliases directory listings
alias ls="ls -G"
alias ll="ls -l -a -G"

# Include commander (https://github.com/focusaurus/commander)
[ -f ~/dotfiles/commander/commander.sh ] && source ~/dotfiles/commander/commander.sh

# Include todo.txt-cli (https://github.com/ginatrapani/todo.txt-cli) if a
# ~/.todo.cfg file exists
if [ -f ~/.todo.cfg ]; then
  export TODOTXT_DEFAULT_ACTION=ls
  source /usr/local/Cellar/todo-txt/2.10/etc/bash_completion.d/todo_completion complete -F _todo td
  alias td='/usr/local/Cellar/todo-txt/2.10/bin/todo.sh'
fi
