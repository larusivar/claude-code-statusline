# Claude Code Statusline

A custom statusline for [Claude Code](https://claude.ai/claude-code) that displays context usage with a visual progress bar, model name, and optional agent name integration.

```
Opus 4.5 | AgentName | ████████░░░░░░│ 42% [2h]
```

## Features

- **Visual context bar** - See at a glance how much context is used
- **Color-coded segments** - Distinguish between cached and new tokens
- **Agent name display** - Show registered Agent Mail agent names
- **Session duration** - Track how long you've been working
- **Lightweight** - Single `jq` call, minimal file I/O

## Requirements

- [Claude Code](https://claude.ai/claude-code) (Anthropic's CLI)
- `jq` 1.6+ - JSON processor
  - macOS: `brew install jq`
  - Ubuntu/Debian: `apt install jq`
  - Fedora: `dnf install jq`
- Bash 3.2+ (macOS default works)
- Terminal with 256-color support (most modern terminals)

## Installation

### 1. Copy the files

```bash
mkdir -p ~/.claude/hooks
curl -o ~/.claude/statusline.sh https://raw.githubusercontent.com/larusivar/claude-code-statusline/main/statusline.sh
curl -o ~/.claude/hooks/capture-agent-name.sh https://raw.githubusercontent.com/larusivar/claude-code-statusline/main/hooks/capture-agent-name.sh
chmod +x ~/.claude/statusline.sh ~/.claude/hooks/capture-agent-name.sh
```

### 2. Configure Claude Code

Add to `~/.claude/settings.json`:

```json
{
  "statusLine": {
    "type": "command",
    "command": "~/.claude/statusline.sh"
  }
}
```

### 3. (Optional) Enable Agent Name Display

If you use [Agent Mail](https://github.com/anthropics/agent-mail) for multi-agent coordination, add this hook to capture agent names:

```json
{
  "statusLine": {
    "type": "command",
    "command": "~/.claude/statusline.sh"
  },
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "mcp__mcp-agent-mail__(register_agent|macro_start_session|create_agent_identity|macro_prepare_thread)",
        "hooks": [
          {
            "type": "command",
            "command": "~/.claude/hooks/capture-agent-name.sh"
          }
        ]
      }
    ]
  }
}
```

## Color Legend

The progress bar uses three colors to show context composition:

| Color | Meaning |
|-------|---------|
| **Dark teal** | Cached tokens from session start (baseline) |
| **Medium teal** | Cache growth during the session |
| **Light cyan** | New tokens added this turn |

This helps you understand:
- How much context is "fixed" (system prompt, file contents)
- How much the conversation has grown
- How much the current turn is adding

## Output Format

```
Model | AgentName | ████████░░░░░░│ 42% [2h]
  │        │              │         │    │
  │        │              │         │    └── Session duration
  │        │              │         └── Context percentage
  │        │              └── Visual bar (14 chars)
  │        └── Agent name (if registered with Agent Mail)
  └── Model display name (Opus, Sonnet, etc.)
```

## Session Files

The statusline stores session data in `/tmp/claude-sl-{session_id}`.

Format: `BASELINE<tab>TOTAL<tab>AGENT_NAME`

Files are cleaned up probabilistically (1 in 20 chance per new session) after 1 day of inactivity.

**Known limitation:** Agent name may briefly disappear if hook and statusline write simultaneously. This is a best-effort tradeoff for ultra-lightweight operation (no file locking).

## Troubleshooting

### "jq required" message
Install jq: `brew install jq` (macOS) or `apt install jq` (Ubuntu)

### Colors look wrong
Ensure your terminal supports 256 colors. Check with:
```bash
echo $TERM  # Should be xterm-256color or similar
```

### Agent name not appearing
1. Verify the hook is configured in `settings.json`
2. Check that you're using Agent Mail registration tools
3. The name appears after the next Claude Code prompt

### Bar not updating
Session files may be stale. Clear them:
```bash
rm -f /tmp/claude-sl-*
```

## License

MIT License - see [LICENSE](LICENSE)

## Contributing

Issues and pull requests welcome!
