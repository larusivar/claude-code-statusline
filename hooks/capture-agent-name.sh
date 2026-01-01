#!/usr/bin/env bash
# shellcheck shell=bash
#
# Capture Agent Name Hook
# Called by Claude Code's PostToolUse hook after Agent Mail registration
#
# Extracts the agent name from the tool response and writes it to the
# session file so the statusline can display it.

set -euo pipefail

# =============================================================================
# Constants
# =============================================================================

readonly MAX_SESSION_ID_LEN=64
readonly SESSION_FILE_PREFIX="/tmp/claude-sl-"

# =============================================================================
# Dependency check
# =============================================================================

if ! command -v jq &>/dev/null; then
    exit 0  # Silent fail - statusline will show generic output
fi

# =============================================================================
# Parse hook input
# =============================================================================

# Read all JSON from stdin (handles multiline)
INPUT=$(cat)

# Extract session ID and agent name
SESSION_ID=$(printf '%s' "$INPUT" | jq -r '.session_id // empty')
AGENT_NAME=$(printf '%s' "$INPUT" | jq -r '.tool_response.name // .tool_response.agent.name // empty')

# Exit if we don't have both values
[[ -z "$SESSION_ID" || -z "$AGENT_NAME" ]] && exit 0

# =============================================================================
# Update session file
# =============================================================================

# Sanitize session ID for filename
SAFE_SESSION="${SESSION_ID//[^a-zA-Z0-9_-]/_}"
SESSION_FILE="${SESSION_FILE_PREFIX}${SAFE_SESSION:0:$MAX_SESSION_ID_LEN}"

# Read existing data or initialize
BASELINE=0
LAST_TOTAL=0

if [[ -f "$SESSION_FILE" ]]; then
    IFS=$'\t' read -r BASELINE LAST_TOTAL _ < "$SESSION_FILE" || true
    [[ "$BASELINE" =~ ^[0-9]+$ ]] || BASELINE=0
    [[ "$LAST_TOTAL" =~ ^[0-9]+$ ]] || LAST_TOTAL=0
fi

# Write back atomically with agent name
printf '%s\t%s\t%s\n' "$BASELINE" "$LAST_TOTAL" "$AGENT_NAME" > "${SESSION_FILE}.tmp"
mv "${SESSION_FILE}.tmp" "$SESSION_FILE"
