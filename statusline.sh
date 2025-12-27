#!/bin/bash
# Claude Code Statusline v2.1.1
# Output: Model | ███▓▓░░░░░░░░│ 31% +500 -100 [2h|↓1.2m↑0.3m|$4]
#
# Bar segments show context composition:
#   Dark teal (█):   Cached baseline at session start
#   Medium teal (▓): Cache growth during session
#   Light cyan (░):  Tokens added this turn

# Single jq call extracts all data as eval-able shell variables
JQ_OUT=$(jq -r '
  @sh "M=\(.model.display_name // "Unknown")",
  @sh "Z=\(.context_window.context_window_size // 200000)",
  @sh "I=\(.context_window.current_usage.input_tokens // 0)",
  @sh "CC=\(.context_window.current_usage.cache_creation_input_tokens // 0)",
  @sh "CR=\(.context_window.current_usage.cache_read_input_tokens // 0)",
  @sh "S=\(.session_id // "")",
  @sh "K=\(.cost.total_cost_usd // 0)",
  @sh "D=\(.cost.total_duration_ms // 0)",
  @sh "A=\(.cost.total_lines_added // 0)",
  @sh "X=\(.cost.total_lines_removed // 0)",
  @sh "TI=\(.context_window.total_input_tokens // 0)",
  @sh "TO=\(.context_window.total_output_tokens // 0)"
' 2>/dev/null) || { printf '\e[38;5;73mClaude Code\e[0m\n'; exit 0; }

[[ -z $JQ_OUT ]] && { printf '\e[38;5;73mClaude Code\e[0m\n'; exit 0; }
eval "$JQ_OUT"

# Validate numerics
[[ $Z =~ ^[0-9]+$ ]] || Z=200000
[[ $K =~ ^[0-9.]+$ ]] || K=0
for v in I CC CR D A X TI TO; do
  [[ ${!v} =~ ^[0-9]+$ ]] || declare "$v=0"
done

# Session baseline tracking (lightweight: /tmp, single read)
BASE=0
if [[ -n $S && $CR -gt 0 ]]; then
  SAFE_S="${S//[^a-zA-Z0-9_-]/_}"
  CF="/tmp/claude-sl-${SAFE_S:0:64}"
  if [[ -f $CF ]]; then
    BASE=$(<"$CF")
    [[ $BASE =~ ^[0-9]+$ ]] || BASE=0
    ((BASE > CR)) && BASE=$CR
  else
    echo "$CR" > "$CF"
    BASE=$CR
    # Cleanup old files (1-in-20 chance, 1-day expiry)
    ((RANDOM % 20 == 0)) && find /tmp -maxdepth 1 -name 'claude-sl-*' -mtime +1 -delete 2>/dev/null &
  fi
fi

# Calculate segments
GROWTH=$((CR - BASE))
NEW=$((I + CC))
TOTAL=$((CR + NEW))

# Calculate percentage
if ((Z > 0)); then
  P=$((TOTAL * 100 / Z))
else
  P=0
fi

# Calculate bar segment widths (14 slots)
if ((Z > 0)); then
  W_BASE=$((BASE * 14 / Z))
  W_GROWTH=$((GROWTH * 14 / Z))
  W_NEW=$((NEW * 14 / Z))
  # Ensure minimum 1 char for non-zero values
  ((BASE > 0 && W_BASE == 0)) && W_BASE=1
  ((GROWTH > 0 && W_GROWTH == 0)) && W_GROWTH=1
  ((NEW > 0 && W_NEW == 0)) && W_NEW=1
else
  W_BASE=0 W_GROWTH=0 W_NEW=0
fi

# Build three-segment bar
SPACES="              "
pos=0
BAR=""
for ((i=0; i<W_BASE && pos<14; i++, pos++)); do BAR+=$'\e[38;5;30m█'; done
for ((i=0; i<W_GROWTH && pos<14; i++, pos++)); do BAR+=$'\e[38;5;73m█'; done
for ((i=0; i<W_NEW && pos<14; i++, pos++)); do BAR+=$'\e[38;5;116m█'; done
BAR+="${SPACES:0:14-pos}"$'\e[38;5;167m│\e[0m'

# Build output
OUT=$'\e[38;5;73m'"$M"$'\e[0m | '"$BAR $P%"

# Lines changed (inline formatting to avoid subshells)
((A > 0 || X > 0)) && {
  ((A >= 1000)) && AF="$((A/1000)).$((A%1000/100))k" || AF=$A
  ((X >= 1000)) && XF="$((X/1000)).$((X%1000/100))k" || XF=$X
  OUT+=$' \e[38;5;33m+'"$AF"$'\e[0m \e[38;5;208m-'"$XF"$'\e[0m'
}

# Session stats
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
