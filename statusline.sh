#!/bin/bash
# Claude Code Statusline v2.0
# Output: Model | ██████░░░░░░░░│ 31% +500 -100 [$4]
#
# Minimal, fast statusline using single jq call with @sh for safe variable extraction.
# Dropped: session cache tracking, MCP counting (complexity for minimal value)

# Single jq call extracts all data as eval-able shell variables
# @sh produces properly quoted shell strings, safe from injection
JQ_OUT=$(jq -r '
  @sh "M=\(.model.display_name // "Unknown")",
  @sh "Z=\(.context_window.context_window_size // 200000)",
  @sh "U=\((.context_window.current_usage // {}) | ((.input_tokens // 0) + (.cache_creation_input_tokens // 0) + (.cache_read_input_tokens // 0)))",
  @sh "K=\(.cost.total_cost_usd // 0)",
  @sh "D=\(.cost.total_duration_ms // 0)",
  @sh "A=\(.cost.total_lines_added // 0)",
  @sh "X=\(.cost.total_lines_removed // 0)",
  @sh "TI=\(.context_window.total_input_tokens // 0)",
  @sh "TO=\(.context_window.total_output_tokens // 0)"
' 2>/dev/null) || { printf '\e[38;5;73mClaude Code\e[0m\n'; exit 0; }

# Check if jq produced output
[[ -z $JQ_OUT ]] && { printf '\e[38;5;73mClaude Code\e[0m\n'; exit 0; }
eval "$JQ_OUT"

# Validate numerics and set defaults
[[ $Z =~ ^[0-9]+$ ]] || Z=200000
for v in U D A X TI TO; do
  [[ ${!v} =~ ^[0-9]+$ ]] || declare "$v=0"
done

# Calculate percentage and bar fill
if ((Z > 0)); then
  P=$((U * 100 / Z))
  F=$((U * 14 / Z))
  ((F > 14)) && F=14
else
  P=0 F=0
fi

# Build bar: filled blocks + spaces + separator
# Using parameter expansion instead of subshell for speed
BLOCKS="██████████████"  # 14 blocks
SPACES="              "  # 14 spaces
BAR=$'\e[38;5;30m'"${BLOCKS:0:F}${SPACES:0:14-F}"$'\e[38;5;167m│\e[0m'

# Build output
OUT=$'\e[38;5;73m'"$M"$'\e[0m | '"$BAR $P%"

# Lines changed (if any)
((A > 0 || X > 0)) && {
  # Format with k suffix for thousands
  fmt() { ((${1:-0} >= 1000)) && echo "$((${1}/1000)).$((${1}%1000/100))k" || echo "${1:-0}"; }
  OUT+=$' \e[38;5;33m+'"$(fmt $A)"$'\e[0m \e[38;5;208m-'"$(fmt $X)"$'\e[0m'
}

# Session stats (if cost > 0 or duration > 0)
if [[ $K != "0" && $K != "0.0"* ]] || ((D > 0)); then
  H=$((D / 3600000))
  IN_M="$((TI / 1000000)).$((TI % 1000000 / 100000))"
  OUT_M="$((TO / 1000000)).$((TO % 1000000 / 100000))"
  COST_INT="${K%.*}"
  OUT+=$' \e[38;5;102m['"${H}h"$'|\e[0m'
  OUT+=$'\e[38;5;102m↓'"${IN_M}m"$'\e[0m'
  OUT+=$' \e[38;5;179m↑'"${OUT_M}m"$'\e[0m'
  OUT+=$' \e[38;5;102m|$'"${COST_INT:-0}]"$'\e[0m'
fi

echo -e "$OUT"
