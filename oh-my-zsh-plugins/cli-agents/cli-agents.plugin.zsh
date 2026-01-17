if command -v claude >/dev/null 2>&1; then
  alias cld="claude"
  alias cldp="claude -p"
  alias cldo="claude --model opus"
  alias clds="claude --model sonnet"
  alias cldys="claude --dangerously-skip-permissions --model sonnet"
  alias cldy="claude --dangerously-skip-permissions --model sonnet"
  alias cldyo="claude --dangerously-skip-permissions --model opus"
  alias cldpy="claude -p --dangerously-skip-permissions"
  alias cldpyo="claude -p --dangerously-skip-permissions --model opus"
  alias cldr="claude --resume"
fi
