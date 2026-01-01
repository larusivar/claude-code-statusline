#!/usr/bin/env bash
# shellcheck shell=bash
#
# Claude Code Statusline v3.0.0
# https://github.com/larusivar/claude-code-statusline
#
# Displays: Model | AgentName | ████████░░░░░░│ 42% [2h]
#
# Bar segments show context composition (same █ char, different colors):
#   Dark teal (color 30):   Cached tokens from session start
#   Medium teal (color 73): Cache growth during session
#   Light cyan (color 116): New tokens this turn

set -euo pipefail

# =============================================================================
# Constants
# =============================================================================

readonly BAR_WIDTH=14
readonly MAX_AGENT_NAME=12
readonly MAX_SESSION_ID_LEN=64
readonly DEFAULT_CTX_SIZE=200000
readonly CLEANUP_PROBABILITY=20  # 1 in N chance to clean old files
readonly SESSION_FILE_PREFIX="/tmp/claude-sl-"

# ANSI color codes (256-color)
readonly C_MODEL='\e[38;5;73m'      # Medium teal for model name
readonly C_BAR_BASE='\e[38;5;30m'   # Dark teal for cached baseline
readonly C_BAR_GROWTH='\e[38;5;73m' # Medium teal for cache growth
readonly C_BAR_NEW='\e[38;5;116m'   # Light cyan for new tokens
readonly C_BAR_SEP='\e[38;5;167m'   # Red for separator
readonly C_DIM='\e[38;5;102m'       # Gray for duration
readonly C_RESET='\e[0m'

# =============================================================================
# Dependency check
# =============================================================================

if ! command -v jq &>/dev/null; then
    printf '%bClaude Code%b (jq required)\n' "$C_MODEL" "$C_RESET"
    exit 0
fi

# =============================================================================
# Parse JSON input from Claude Code
# =============================================================================

JQ_OUTPUT=$(jq -r '
  @sh "MODEL=\(.model.display_name // "Unknown")",
  @sh "CTX_SIZE=\(.context_window.context_window_size // 200000)",
  @sh "INPUT_TOKENS=\(.context_window.current_usage.input_tokens // 0)",
  @sh "CACHE_CREATION=\(.context_window.current_usage.cache_creation_input_tokens // 0)",
  @sh "CACHE_READ=\(.context_window.current_usage.cache_read_input_tokens // 0)",
  @sh "SESSION_ID=\(.session_id // "")",
  @sh "DURATION_MS=\(.cost.total_duration_ms // 0)"
' 2>/dev/null) || {
    printf '%bClaude Code%b\n' "$C_MODEL" "$C_RESET"
    exit 0
}

[[ -z "$JQ_OUTPUT" ]] && {
    printf '%bClaude Code%b\n' "$C_MODEL" "$C_RESET"
    exit 0
}

eval "$JQ_OUTPUT"

# =============================================================================
# Validate numeric values
# =============================================================================

[[ "$CTX_SIZE" =~ ^[0-9]+$ ]] || CTX_SIZE=$DEFAULT_CTX_SIZE
[[ "$INPUT_TOKENS" =~ ^[0-9]+$ ]] || INPUT_TOKENS=0
[[ "$CACHE_CREATION" =~ ^[0-9]+$ ]] || CACHE_CREATION=0
[[ "$CACHE_READ" =~ ^[0-9]+$ ]] || CACHE_READ=0
[[ "$DURATION_MS" =~ ^[0-9]+$ ]] || DURATION_MS=0

# =============================================================================
# Session file tracking
# Format: BASE<tab>LAST_TOTAL<tab>AGENT_NAME
# =============================================================================

BASELINE=0
AGENT_NAME=""

if [[ -n "$SESSION_ID" ]]; then
    SAFE_SESSION="${SESSION_ID//[^a-zA-Z0-9_-]/_}"
    SESSION_FILE="${SESSION_FILE_PREFIX}${SAFE_SESSION:0:$MAX_SESSION_ID_LEN}"

    if [[ -f "$SESSION_FILE" ]]; then
        IFS=$'\t' read -r BASELINE _LAST_TOTAL AGENT_NAME < "$SESSION_FILE" || true
        [[ "$BASELINE" =~ ^[0-9]+$ ]] || BASELINE=0
        # Adjust baseline if cache was compressed
        ((BASELINE > CACHE_READ && CACHE_READ > 0)) && BASELINE=$CACHE_READ
    else
        BASELINE=$CACHE_READ
        # Probabilistic cleanup of old session files (1 in N chance)
        if ((RANDOM % CLEANUP_PROBABILITY == 0)); then
            find /tmp -maxdepth 1 -name 'claude-sl-*' -mtime +1 -delete 2>/dev/null &
        fi
    fi
fi

# =============================================================================
# Calculate context segments
# =============================================================================

CACHE_GROWTH=$((CACHE_READ - BASELINE))
NEW_TOKENS=$((INPUT_TOKENS + CACHE_CREATION))
TOTAL_TOKENS=$((CACHE_READ + NEW_TOKENS))

# Update session file atomically
if [[ -n "${SESSION_FILE:-}" ]]; then
    # Re-read agent name in case hook updated it (best-effort race mitigation)
    if [[ -f "$SESSION_FILE" ]]; then
        IFS=$'\t' read -r _ _ FRESH_AGENT < "$SESSION_FILE" || true
        [[ -n "$FRESH_AGENT" ]] && AGENT_NAME="$FRESH_AGENT"
    fi
    printf '%s\t%s\t%s\n' "$BASELINE" "$TOTAL_TOKENS" "$AGENT_NAME" > "${SESSION_FILE}.tmp"
    mv "${SESSION_FILE}.tmp" "$SESSION_FILE"
fi

# Calculate percentage
if ((CTX_SIZE > 0)); then
    PERCENT=$((TOTAL_TOKENS * 100 / CTX_SIZE))
else
    PERCENT=0
fi

# =============================================================================
# Build visual bar
# =============================================================================

# Calculate segment widths
if ((CTX_SIZE > 0)); then
    WIDTH_BASE=$((BASELINE * BAR_WIDTH / CTX_SIZE))
    WIDTH_GROWTH=$((CACHE_GROWTH * BAR_WIDTH / CTX_SIZE))
    WIDTH_NEW=$((NEW_TOKENS * BAR_WIDTH / CTX_SIZE))
    # Ensure minimum 1 char for non-zero values
    ((BASELINE > 0 && WIDTH_BASE == 0)) && WIDTH_BASE=1
    ((CACHE_GROWTH > 0 && WIDTH_GROWTH == 0)) && WIDTH_GROWTH=1
    ((NEW_TOKENS > 0 && WIDTH_NEW == 0)) && WIDTH_NEW=1
else
    WIDTH_BASE=0
    WIDTH_GROWTH=0
    WIDTH_NEW=0
fi

# Build bar string
SPACES="              "  # 14 spaces
pos=0
BAR=""
for ((i = 0; i < WIDTH_BASE && pos < BAR_WIDTH; i++, pos++)); do
    BAR+="${C_BAR_BASE}█"
done
for ((i = 0; i < WIDTH_GROWTH && pos < BAR_WIDTH; i++, pos++)); do
    BAR+="${C_BAR_GROWTH}█"
done
for ((i = 0; i < WIDTH_NEW && pos < BAR_WIDTH; i++, pos++)); do
    BAR+="${C_BAR_NEW}█"
done
BAR+="${SPACES:0:BAR_WIDTH-pos}${C_BAR_SEP}│${C_RESET}"

# =============================================================================
# Build output string
# =============================================================================

# Agent name (optional, truncated)
if [[ -n "$AGENT_NAME" ]]; then
    AGENT_DISPLAY=" | ${AGENT_NAME:0:$MAX_AGENT_NAME}"
else
    AGENT_DISPLAY=""
fi

OUTPUT="${C_MODEL}${MODEL}${C_RESET}${AGENT_DISPLAY} | ${BAR} ${PERCENT}%"

# Session duration
if ((DURATION_MS > 0)); then
    HOURS=$((DURATION_MS / 3600000))
    OUTPUT+=" ${C_DIM}[${HOURS}h]${C_RESET}"
fi

printf '%b\n' "$OUTPUT"
