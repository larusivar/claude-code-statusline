#!/bin/bash
# Claude Code Statusline v1.1.0
# Output: Model | ███████░░░░░░░│ 49% mcp:4 +1k -23 [2h|↓1.2m↑0.3m|$12]
#
# Bar segments: [cached base][session growth][new tokens][padding][separator]
# Colors: dark teal (cached) → medium teal (growth) → light cyan (new) │ red separator

set -o pipefail

# === Configuration ===
R=$'\e[0m'                      # Reset
CACHE_DIR=~/.claude/statusline-cache
BAR_WIDTH=15                    # Context bar width (including separator)

# Colors (256-color palette)
C_MODEL=73                      # Model name: teal
C_DIM=102                       # Dim text: gray
C_CACHED=30                     # Cached tokens: dark teal
C_GROWTH=73                     # Session growth: medium teal
C_NEW=116                       # New tokens: light cyan
C_SEP=167                       # Bar separator: red
C_MCP=109                       # MCP count: muted cyan
C_ADD=33                        # Lines added: blue
C_DEL=208                       # Lines removed: orange
C_UP=179                        # Upload: gold

# === Parse JSON Input ===
# Reads from stdin, provides safe defaults for missing fields
json_data=$(cat)
if ! parse_output=$(echo "$json_data" | jq -r '
  (.model.display_name // "Unknown"),
  (.workspace.current_dir // "."),
  (.session_id // ""),
  (.context_window.context_window_size // 200000),
  (.context_window.current_usage.input_tokens // 0),
  (.context_window.current_usage.cache_creation_input_tokens // 0),
  (.context_window.current_usage.cache_read_input_tokens // 0),
  (.cost.total_cost_usd // 0),
  (.cost.total_duration_ms // 0),
  (.cost.total_lines_added // 0),
  (.cost.total_lines_removed // 0),
  (.context_window.total_input_tokens // 0),
  (.context_window.total_output_tokens // 0)
' 2>/dev/null); then
  # jq failed - show minimal fallback
  echo -e "\e[38;5;${C_MODEL}mClaude Code$R \e[38;5;${C_DIM}m(no data)$R"
  exit 0
fi

# Read parsed values into variables
{ read -r MODEL; read -r WORKSPACE; read -r SESSION_ID; read -r CTX_SIZE
  read -r INPUT_TOKENS; read -r CACHE_CREATE; read -r CACHE_READ
  read -r COST_USD; read -r DURATION_MS; read -r LINES_ADD; read -r LINES_DEL
  read -r TOTAL_IN; read -r TOTAL_OUT; } <<< "$parse_output"

# Validate numeric fields (default to 0 if non-numeric)
for var in CTX_SIZE INPUT_TOKENS CACHE_CREATE CACHE_READ DURATION_MS LINES_ADD LINES_DEL TOTAL_IN TOTAL_OUT; do
  [[ ${!var} =~ ^[0-9]+$ ]] || declare "$var=0"
done

# === Calculate Context Usage ===
NEW_TOKENS=$((INPUT_TOKENS + CACHE_CREATE))      # Tokens added this turn
TOTAL_USED=$((CACHE_READ + NEW_TOKENS))          # Total context used
PCT=$((CTX_SIZE > 0 ? TOTAL_USED * 100 / CTX_SIZE : 0))

# === Session Cache (track initial cache baseline) ===
INITIAL_CACHE=0
if [[ -n $SESSION_ID && $CACHE_READ -gt 0 ]]; then
  mkdir -p "$CACHE_DIR"
  # Sanitize session ID for safe filename
  SAFE_ID="${SESSION_ID//[^a-zA-Z0-9_-]/_}"
  CACHE_FILE="$CACHE_DIR/$SAFE_ID"

  if [[ -f $CACHE_FILE ]]; then
    INITIAL_CACHE=$(<"$CACHE_FILE")
    # Validate cached value
    [[ $INITIAL_CACHE =~ ^[0-9]+$ ]] || INITIAL_CACHE=0
    # Clamp if cache shrunk (shouldn't happen, but be safe)
    ((INITIAL_CACHE > CACHE_READ)) && INITIAL_CACHE=$CACHE_READ
  else
    echo "$CACHE_READ" > "$CACHE_FILE"
    INITIAL_CACHE=$CACHE_READ
    # Cleanup old cache files (probabilistic, 1-in-10)
    ((RANDOM % 10 == 0)) && find "$CACHE_DIR" -mtime +7 -delete 2>/dev/null &
  fi
fi

# Session growth = how much cache grew since session start
SESSION_GROWTH=$((CACHE_READ > INITIAL_CACHE ? CACHE_READ - INITIAL_CACHE : 0))

# === Count MCP Servers ===
MCP_COUNT=0
MCP_FILE="$WORKSPACE/.mcp.json"
LOCAL_SETTINGS="$WORKSPACE/.claude/settings.local.json"

if [[ -f $MCP_FILE ]]; then
  if [[ -f $LOCAL_SETTINGS ]]; then
    # Check enabledMcpjsonServers first
    MCP_COUNT=$(jq -r '(.enabledMcpjsonServers // []) | length' "$LOCAL_SETTINGS" 2>/dev/null) || MCP_COUNT=0
    if [[ $MCP_COUNT == 0 || ! $MCP_COUNT =~ ^[0-9]+$ ]]; then
      # Fall back to counting non-disabled servers
      MCP_COUNT=$(jq -rs '
        (.[1].disabledMcpjsonServers // []) as $disabled |
        .[0].mcpServers | keys | map(select(. as $k | $disabled | index($k) | not)) | length
      ' "$MCP_FILE" "$LOCAL_SETTINGS" 2>/dev/null) || MCP_COUNT=0
    fi
  else
    # No local settings, count all servers in .mcp.json
    MCP_COUNT=$(jq -r '.mcpServers | keys | length' "$MCP_FILE" 2>/dev/null) || MCP_COUNT=0
  fi
fi
[[ $MCP_COUNT =~ ^[0-9]+$ ]] || MCP_COUNT=0

# === Build Context Bar ===
# Calculate segment widths (reserve 1 char for separator)
USABLE_WIDTH=$((BAR_WIDTH - 1))
calc_width() { ((CTX_SIZE > 0 && $1 > 0)) && echo $(($1 * USABLE_WIDTH / CTX_SIZE)) || echo 0; }

W_CACHED=$(calc_width $INITIAL_CACHE)
W_GROWTH=$(calc_width $SESSION_GROWTH)
W_NEW=$(calc_width $NEW_TOKENS)

# Ensure minimum 1 char for non-zero segments
((INITIAL_CACHE > 0 && W_CACHED == 0)) && W_CACHED=1
((SESSION_GROWTH > 0 && W_GROWTH == 0)) && W_GROWTH=1
((NEW_TOKENS > 0 && W_NEW == 0)) && W_NEW=1

# Build bar string - track position to prevent overflow
BAR=""
pos=0
for ((i = 0; i < W_CACHED && pos < USABLE_WIDTH; i++, pos++)); do
  BAR+="\e[38;5;${C_CACHED}m█"
done
for ((i = 0; i < W_GROWTH && pos < USABLE_WIDTH; i++, pos++)); do
  BAR+="\e[38;5;${C_GROWTH}m█"
done
for ((i = 0; i < W_NEW && pos < USABLE_WIDTH; i++, pos++)); do
  BAR+="\e[38;5;${C_NEW}m█"
done

# Pad remaining space and add separator
while ((pos < USABLE_WIDTH)); do
  BAR+=" "
  ((pos++))
done
BAR+="\e[38;5;${C_SEP}m│$R"

# === Format Numbers ===
fmt_k() {
  if ((${1:-0} >= 1000)); then
    local k=$(($1 / 1000)) d=$((($1 % 1000) / 100))
    ((d > 0)) && printf "%d.%dk" $k $d || printf "%dk" $k
  else
    echo "${1:-0}"
  fi
}

# === Build Output ===
OUT="\e[38;5;${C_MODEL}m${MODEL}$R \e[38;5;${C_DIM}m|$R $BAR $PCT%"

# MCP servers (if any)
((MCP_COUNT > 0)) && OUT+=" \e[38;5;${C_MCP}mmcp:${MCP_COUNT}$R"

# Lines changed (if any)
if ((LINES_ADD > 0 || LINES_DEL > 0)); then
  OUT+=" \e[38;5;${C_ADD}m+$(fmt_k $LINES_ADD)$R"
  OUT+=" \e[38;5;${C_DEL}m-$(fmt_k $LINES_DEL)$R"
fi

# Session stats (if we have cost data)
# Check for non-zero cost: handle both integer and float formats
has_cost=0
if [[ -n $COST_USD && $COST_USD != "0" && $COST_USD != "0.00" && $COST_USD != "0.0" ]]; then
  # Remove decimal point and leading zeros, check if anything meaningful remains
  cost_check="${COST_USD//./}"
  cost_check="${cost_check#"${cost_check%%[!0]*}"}"  # Remove leading zeros (POSIX compliant)
  [[ -n $cost_check ]] && has_cost=1
fi

if ((has_cost || DURATION_MS > 0)); then
  HOURS=$((DURATION_MS / 3600000))
  IN_M=$(printf "%d.%d" $((TOTAL_IN / 1000000)) $(((TOTAL_IN % 1000000) / 100000)))
  OUT_M=$(printf "%d.%d" $((TOTAL_OUT / 1000000)) $(((TOTAL_OUT % 1000000) / 100000)))
  COST_INT="${COST_USD%.*}"

  OUT+=" \e[38;5;${C_DIM}m[${HOURS}h|$R"
  OUT+=" \e[38;5;${C_DIM}m↓${IN_M}m$R"
  OUT+=" \e[38;5;${C_UP}m↑${OUT_M}m$R"
  OUT+=" \e[38;5;${C_DIM}m|\$${COST_INT:-0}]$R"
fi

echo -e "$OUT"
